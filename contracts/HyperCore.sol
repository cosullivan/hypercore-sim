// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { DoubleEndedQueue } from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import { SpotERC20 } from "./SpotERC20.sol";
import { L1Read } from "./L1Read.sol";
import { L1Write } from "./L1Write.sol";
import { HyperCoreLib } from "./HyperCoreLib.sol";

import "hardhat/console.sol";

contract HyperCore {
  using Address for address payable;
  using SafeCast for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;
  using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

  mapping(uint64 token => L1Read.TokenInfo) _tokens;

  struct WithdrawRequest {
    uint40 lockedUntilTimestamp;
    uint64 amount;
  }

  struct WithdrawQueue {
    uint64 total;
    DoubleEndedQueue.Bytes32Deque queue;
  }

  struct Account {
    bool created;
    uint64 perp;
    mapping(uint64 => uint64) spot;
    mapping(address vault => L1Read.UserVaultEquity) vaultEquity;
    uint64 staking;
    mapping(address validator => L1Read.Delegation) delegations;
    WithdrawQueue withdrawing;
  }

  mapping(address account => Account) _accounts;

  mapping(address vault => uint64) _vaultEquity;

  EnumerableSet.AddressSet _validators;

  EnumerableSet.AddressSet _stakers;

  constructor() {
    registerTokenInfo(
      HyperCoreLib.KNOWN_TOKEN_HYPE,
      L1Read.TokenInfo({
        name: "HYPE",
        spots: new uint64[](0),
        deployerTradingFeeShare: 0,
        deployer: address(0),
        evmContract: address(0),
        szDecimals: 2,
        weiDecimals: 8,
        evmExtraWeiDecimals: 0
      })
    );
  }

  receive() external payable {}

  modifier whenAccountCreated(address sender) {
    if (_accounts[sender].created == false) {
      return;
    }
    _;
  }

  function registerTokenInfo(uint64 index, L1Read.TokenInfo memory tokenInfo) public {
    require(bytes(_tokens[index].name).length == 0);
    require(tokenInfo.evmContract == address(0));

    _tokens[index] = tokenInfo;
  }

  function deploySpotERC20(uint64 index) external returns (SpotERC20 spot) {
    require(_tokens[index].evmContract == address(0));

    spot = new SpotERC20(index, _tokens[index]);

    _tokens[index].evmContract = address(spot);
  }

  /// @dev account creation can be forced when there isnt a reliance on testing that workflow.
  function forceAccountCreation(address account) public {
    _accounts[account].created = true;
  }

  function forceSpot(address account, uint64 token, uint64 _wei) public {
    forceAccountCreation(account);
    _accounts[account].spot[token] = _wei;
  }

  function forcePerp(address account, uint64 usd) public {
    forceAccountCreation(account);
    _accounts[account].perp = usd;
  }

  function forceVaultEquity(address account, address vault, uint64 usd, uint64 lockedUntilTimestamp) public {
    forceAccountCreation(account);

    _vaultEquity[vault] -= _accounts[account].vaultEquity[vault].equity;
    _vaultEquity[vault] += usd;

    _accounts[account].vaultEquity[vault].equity = usd;
    _accounts[account].vaultEquity[vault].lockedUntilTimestamp = lockedUntilTimestamp > 0
      ? lockedUntilTimestamp
      : uint64((block.timestamp + 3600) * 1000);
  }

  function tokenExists(uint64 token) private view returns (bool) {
    return bytes(_tokens[token].name).length > 0;
  }

  /// @dev unstaking takes 7 days and after which it will automatically appear in the users
  /// spot balance so we need to check this at the end of each operation to simulate that.
  function flushCWithdrawQueue() public {
    for (uint256 i = 0; i < _stakers.length(); i++) {
      address user = _stakers.at(i);
      WithdrawQueue storage withdrawQueue = _accounts[user].withdrawing;
      while (withdrawQueue.queue.length() > 0) {
        WithdrawRequest memory request = deserializeWithdrawRequest(withdrawQueue.queue.front());

        if (request.lockedUntilTimestamp > block.timestamp) {
          break;
        }

        withdrawQueue.queue.popFront();

        withdrawQueue.total -= request.amount;
        _accounts[user].spot[HyperCoreLib.KNOWN_TOKEN_HYPE] += request.amount;
      }
    }
  }

  function executeTokenTransfer(
    address,
    uint64 token,
    address from,
    uint256 value
  ) public payable whenAccountCreated(from) {
    require(tokenExists(token));
    _accounts[from].spot[token] += HyperCoreLib.toWei(value, _tokens[token].evmExtraWeiDecimals);
  }

  function executeNativeTransfer(address, address from, uint256 value) public payable whenAccountCreated(from) {
    _accounts[from].spot[HyperCoreLib.KNOWN_TOKEN_HYPE] += (value / 1e10).toUint64();
  }

  function executeSpot(
    address sender,
    address destination,
    uint64 token,
    uint64 _wei
  ) public whenAccountCreated(sender) {
    if (_wei > _accounts[sender].spot[token]) {
      return;
    }

    _accounts[sender].spot[token] -= _wei;

    if (destination == HyperCoreLib.systemAddress(token)) {
      if (token == HyperCoreLib.KNOWN_TOKEN_HYPE) {
        payable(sender).sendValue(_wei * 1e10);
        return;
      }
      SpotERC20(_tokens[token].evmContract).transferFrom(
        destination,
        sender,
        HyperCoreLib.fromWei(_wei, _tokens[token].evmExtraWeiDecimals)
      );
      return;
    }

    _accounts[destination].spot[token] += _wei;

    if (_accounts[destination].created == false) {
      // TODO: this should deduct some HYPE balance from the sender in order to create the destination
      _accounts[destination].created = true;
    }
  }

  function executeUsdClassTransfer(address sender, uint64 ntl, bool toPerp) public whenAccountCreated(sender) {
    if (toPerp) {
      if (HyperCoreLib.fromPerp(ntl) <= _accounts[sender].spot[HyperCoreLib.KNOWN_TOKEN_USDC]) {
        _accounts[sender].perp += ntl;
        _accounts[sender].spot[HyperCoreLib.KNOWN_TOKEN_USDC] -= HyperCoreLib.fromPerp(ntl);
      }
    } else {
      if (ntl <= _accounts[sender].perp) {
        _accounts[sender].perp -= ntl;
        _accounts[sender].spot[HyperCoreLib.KNOWN_TOKEN_USDC] += HyperCoreLib.fromPerp(ntl);
      }
    }
  }

  function executeVaultTransfer(
    address sender,
    address vault,
    bool isDeposit,
    uint64 usd
  ) public whenAccountCreated(sender) {
    if (isDeposit) {
      if (usd <= _accounts[sender].perp) {
        _accounts[sender].vaultEquity[vault].equity += usd;
        _accounts[sender].vaultEquity[vault].lockedUntilTimestamp = uint64((block.timestamp + 3600) * 1000);
        _accounts[sender].perp -= usd;
        _vaultEquity[vault] += usd;
      }
    } else {
      L1Read.UserVaultEquity storage userVaultEquity = _accounts[sender].vaultEquity[vault];

      // a zero amount means withdraw the entire amount
      usd = usd == 0 ? userVaultEquity.equity : usd;

      // the vaults have a minimum withdraw of 1 / 100,000,000
      if (usd < _vaultEquity[vault] / 1e8) {
        return;
      }

      if (usd <= userVaultEquity.equity && userVaultEquity.lockedUntilTimestamp / 1000 <= block.timestamp) {
        userVaultEquity.equity -= usd;
        _accounts[sender].perp += usd;
      }
    }
  }

  function executeCDeposit(address sender, uint64 _wei) public whenAccountCreated(sender) {
    if (_wei < _accounts[sender].spot[HyperCoreLib.KNOWN_TOKEN_HYPE]) {
      _accounts[sender].spot[HyperCoreLib.KNOWN_TOKEN_HYPE] -= _wei;
      _accounts[sender].staking += _wei;
    }
  }

  function executeCWithdrawal(address sender, uint64 _wei) public whenAccountCreated(sender) {
    if (_wei < _accounts[sender].staking) {
      _accounts[sender].staking -= _wei;

      _accounts[sender].withdrawing.total += _wei;
      _accounts[sender].withdrawing.queue.pushBack(
        serializeWithdrawRequest(WithdrawRequest(uint40(block.timestamp + 7 days), _wei))
      );
    }
  }

  function serializeWithdrawRequest(WithdrawRequest memory request) private pure returns (bytes32) {
    return bytes32((uint256(request.amount) << 40) | uint40(request.lockedUntilTimestamp));
  }

  function deserializeWithdrawRequest(bytes32 data) private pure returns (WithdrawRequest memory request) {
    request.lockedUntilTimestamp = uint40(uint256(data));
    request.amount = uint64(uint256(data) >> 40);
  }

  function executeTokenDelegate(address sender, address validator, uint64 _wei, bool isUndelegate) public {
    require(_validators.contains(validator));

    if (isUndelegate) {
      L1Read.Delegation storage delegation = _accounts[sender].delegations[validator];
      if (_wei <= delegation.amount && block.timestamp * 1000 > delegation.lockedUntilTimestamp) {
        _accounts[sender].staking += _wei;
        delegation.amount -= _wei;
      }
    } else {
      if (_wei <= _accounts[sender].staking) {
        _stakers.add(sender);
        _accounts[sender].staking -= _wei;
        _accounts[sender].delegations[validator].amount += _wei;
        _accounts[sender].delegations[validator].lockedUntilTimestamp = ((block.timestamp + 84600) * 1000).toUint64();
      }
    }
  }

  function readTokenInfo(uint32 token) public view returns (L1Read.TokenInfo memory) {
    require(tokenExists(token));
    return _tokens[token];
  }

  function readSpotBalance(address account, uint64 token) public view returns (L1Read.SpotBalance memory) {
    require(tokenExists(token));
    return L1Read.SpotBalance({ total: _accounts[account].spot[token], entryNtl: 0, hold: 0 });
  }

  function readWithdrawable(address account) public view returns (L1Read.Withdrawable memory) {
    return L1Read.Withdrawable({ withdrawable: _accounts[account].perp });
  }

  function readUserVaultEquity(address user, address vault) public view returns (L1Read.UserVaultEquity memory) {
    return _accounts[user].vaultEquity[vault];
  }

  function readDelegations(address user) public view returns (L1Read.Delegation[] memory userDelegations) {
    address[] memory validators = _validators.values();

    userDelegations = new L1Read.Delegation[](validators.length);
    for (uint256 i; i < userDelegations.length; i++) {
      userDelegations[i].validator = validators[i];

      L1Read.Delegation memory delegation = _accounts[user].delegations[validators[i]];
      userDelegations[i].amount = delegation.amount;
      userDelegations[i].lockedUntilTimestamp = delegation.lockedUntilTimestamp;
    }
  }

  function readDelegatorSummary(address user) public view returns (L1Read.DelegatorSummary memory summary) {
    address[] memory validators = _validators.values();

    for (uint256 i; i < validators.length; i++) {
      L1Read.Delegation memory delegation = _accounts[user].delegations[validators[i]];
      summary.delegated += delegation.amount;
    }

    summary.undelegated = _accounts[user].staking;

    summary.nPendingWithdrawals = _accounts[user].withdrawing.queue.length().toUint64();

    for (uint256 i; i < summary.nPendingWithdrawals; i++) {
      WithdrawRequest memory request = deserializeWithdrawRequest(_accounts[user].withdrawing.queue.at(i));
      summary.totalPendingWithdrawal += request.amount;
    }
  }

  function readPosition(address user, uint16 perp) public view returns (L1Read.Position memory) {
    // TODO
  }
}
