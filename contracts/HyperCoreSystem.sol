// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { HyperCoreWrite } from "./HyperCoreWrite.sol";

/// @dev handles receiving HYPE and transferring
contract HyperCoreSystem {
  HyperCoreWrite private _hyperCoreWrite;

  function setHyperCoreWrite(HyperCoreWrite hyperCoreWrite) public {
    _hyperCoreWrite = hyperCoreWrite;
  }

  receive() external payable {
    _hyperCoreWrite.nativeTransferCallback{ value: msg.value }(msg.sender, msg.sender, msg.value);
  }
}
