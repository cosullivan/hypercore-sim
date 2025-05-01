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
    mapping(uint64 => uint64) spot;
  }

  mapping(address account => Account) _accounts;

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

  function readSpotBalance(address account, uint64 token) public view returns (L1Read.SpotBalance memory) {
    require(tokenExists(token));
    return L1Read.SpotBalance({ total: _accounts[account].spot[token], entryNtl: 0, hold: 0 });
  }

  function readTokenInfo(uint32 token) public view returns (L1Read.TokenInfo memory) {
    require(tokenExists(token));
    return _tokens[token];
  }
}
