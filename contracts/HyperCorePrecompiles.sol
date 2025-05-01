// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { SPOT_BALANCE_PRECOMPILE_ADDRESS } from "./L1Read.sol";
import { HyperCore } from "./HyperCore.sol";

contract HyperCorePrecompiles {
  HyperCore private _hyperCore;

  receive() external payable {}

  function setHyperCore(HyperCore hyperCore) public {
    _hyperCore = hyperCore;
  }

  fallback(bytes calldata data) external returns (bytes memory) {
    // if (address(this) == 0x000000000000000000000000000000000000080C) {

    // }
    if (address(this) == SPOT_BALANCE_PRECOMPILE_ADDRESS) {
      (address user, uint64 token) = abi.decode(data, (address, uint64));
      return abi.encode(_hyperCore.readSpotBalance(user, token));
    }

    // if (address(this) == PrecompileLib.VAULT_EQUITY_PRECOMPILE_ADDRESS) {
    //   (address user, address vault) = abi.decode(data, (address, address));
    //   return abi.encode(userVaultEquity(user, vault));
    // }

    // if (address(this) == PrecompileLib.WITHDRAWABLE_PRECOMPILE_ADDRESS) {
    //   address user = abi.decode(data, (address));
    //   return abi.encode(withdrawable(user));
    // }

    // if (address(this) == PrecompileLib.DELEGATIONS_PRECOMPILE_ADDRESS) {
    //   address user = abi.decode(data, (address));
    //   return abi.encode(delegations(user));
    // }

    // if (address(this) == PrecompileLib.DELEGATOR_SUMMARY_PRECOMPILE_ADDRESS) {
    //   address user = abi.decode(data, (address));
    //   return abi.encode(delegatorSummary(user));
    // }

    revert();
  }
}
