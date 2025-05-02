// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { L1Write } from "./L1Write.sol";
import { HyperCore } from "./HyperCore.sol";

import "hardhat/console.sol";

contract HyperCoreWrite is L1Write {
  using Address for address;

  bytes[] private _actionQueue;

  uint256[] private _actionQueueValues;

  HyperCore private _hyperCore;

  function setHyperCore(HyperCore hyperCore) public {
    _hyperCore = hyperCore;
  }

  function enqueueAction(bytes memory data, uint256 value) public {
    _actionQueue.push(data);
    _actionQueueValues.push(value);
  }

  function flushActionQueue() external {
    for (uint256 i = 0; i < _actionQueue.length; i++) {
      address(_hyperCore).functionCallWithValue(_actionQueue[i], _actionQueueValues[i]);
    }

    delete _actionQueue;
    delete _actionQueueValues;

    _hyperCore.flushCWithdrawQueue();
  }

  function tokenTransferCallback(uint64 token, address from, uint256 value) public {
    // there's a special case when transferring to the L1 via the system address which
    // is that the balance isn't reflected on the L1 until after the EVM block has finished
    // and the subsequent EVM block has been processed, this means that the balance can be
    // in limbo for the user
    tokenTransferCallback(msg.sender, token, from, value);
  }

  function tokenTransferCallback(address sender, uint64 token, address from, uint256 value) public {
    enqueueAction(abi.encodeCall(HyperCore.executeTokenTransfer, (sender, token, from, value)), 0);
  }

  function nativeTransferCallback(address sender, address from, uint256 value) public payable {
    enqueueAction(abi.encodeCall(HyperCore.executeNativeTransfer, (sender, from, value)), value);
  }

  function sendIocOrder(uint32 asset, bool isBuy, uint64 limitPx, uint64 sz) external {
    emit IocOrder(msg.sender, asset, isBuy, limitPx, sz);
  }

  function sendVaultTransfer(address vault, bool isDeposit, uint64 usd) external {
    enqueueAction(abi.encodeCall(HyperCore.executeVaultTransfer, (msg.sender, vault, isDeposit, usd)), 0);

    emit VaultTransfer(msg.sender, vault, isDeposit, usd);
  }

  function sendTokenDelegate(address validator, uint64 _wei, bool isUndelegate) external {
    enqueueAction(abi.encodeCall(HyperCore.executeTokenDelegate, (msg.sender, validator, _wei, isUndelegate)), 0);

    emit TokenDelegate(msg.sender, validator, _wei, isUndelegate);
  }

  function sendCDeposit(uint64 _wei) external {
    enqueueAction(abi.encodeCall(HyperCore.executeCDeposit, (msg.sender, _wei)), 0);

    emit CDeposit(msg.sender, _wei);
  }

  function sendCWithdrawal(uint64 _wei) external {
    enqueueAction(abi.encodeCall(HyperCore.executeCWithdrawal, (msg.sender, _wei)), 0);

    emit CWithdrawal(msg.sender, _wei);
  }

  function sendSpot(address destination, uint64 token, uint64 _wei) external {
    enqueueAction(abi.encodeCall(HyperCore.executeSpot, (msg.sender, destination, token, _wei)), 0);

    emit SpotSend(msg.sender, destination, token, _wei);
  }

  function sendUsdClassTransfer(uint64 ntl, bool toPerp) external {
    enqueueAction(abi.encodeCall(HyperCore.executeUsdClassTransfer, (msg.sender, ntl, toPerp)), 0);

    emit UsdClassTransfer(msg.sender, ntl, toPerp);
  }
}
