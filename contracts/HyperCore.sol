// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SpotERC20 } from "./SpotERC20.sol";
import { L1Read } from "./L1Read.sol";
import { L1Write } from "./L1Write.sol";
import { HyperCoreLib } from "./HyperCoreLib.sol";

import "hardhat/console.sol";

contract HyperCore {
  using Address for address payable;
  using SafeCast for uint256;

  mapping(uint64 token => L1Read.TokenInfo) _tokens;

  struct Account {
    bool created;
    uint64 perp;
    mapping(uint64 => uint64) spot;
    mapping(address vault => L1Read.UserVaultEquity) vaultEquity;
  }

  mapping(address account => Account) _accounts;

  mapping(address vault => uint64) _vaultEquity;

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

  function flushCWithdrawQueue() public {
    // TODO
  }

  function executeTokenTransfer(address, uint64 token, address from, uint256 value) public payable {
    require(tokenExists(token));

    if (_accounts[from].created == false) {
      // silently fail
      return;
    }

    _accounts[from].spot[token] += HyperCoreLib.toWei(value, _tokens[token].evmExtraWeiDecimals);
  }

  function executeNativeTransfer(address, address from, uint256 value) public payable {
    if (_accounts[from].created == false) {
      return;
    }
    _accounts[from].spot[HyperCoreLib.KNOWN_TOKEN_HYPE] += (value / 1e10).toUint64();
  }

  function executeSpot(address sender, address destination, uint64 token, uint64 _wei) public {
    if (_accounts[sender].created == false || _wei > _accounts[sender].spot[token]) {
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

  function executeUsdClassTransfer(address sender, uint64 ntl, bool toPerp) public {
    if (_accounts[sender].created == false) {
      return;
    }

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

  function executeVaultTransfer(address sender, address vault, bool isDeposit, uint64 usd) public {
    if (_accounts[sender].created == false) {
      return;
    }

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
    // TODO
  }

  function readDelegatorSummary(address user) public view returns (L1Read.DelegatorSummary memory summary) {
    // TODO
  }

  function readPosition(address user, uint16 perp) public view returns (L1Read.Position memory) {
    // TODO
  }
}
