// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { POSITION_PRECOMPILE_ADDRESS, SPOT_BALANCE_PRECOMPILE_ADDRESS, WITHDRAWABLE_PRECOMPILE_ADDRESS, VAULT_EQUITY_PRECOMPILE_ADDRESS, DELEGATIONS_PRECOMPILE_ADDRESS, DELEGATOR_SUMMARY_PRECOMPILE_ADDRESS } from "./L1Read.sol";
import { HyperCore } from "./HyperCore.sol";

contract HyperCorePrecompiles {
  HyperCore private _hyperCore;

  receive() external payable {}

  function setHyperCore(HyperCore hyperCore) public {
    _hyperCore = hyperCore;
  }

  fallback(bytes calldata data) external returns (bytes memory) {
    if (address(this) == SPOT_BALANCE_PRECOMPILE_ADDRESS) {
      (address user, uint64 token) = abi.decode(data, (address, uint64));
      return abi.encode(_hyperCore.readSpotBalance(user, token));
    }

    if (address(this) == VAULT_EQUITY_PRECOMPILE_ADDRESS) {
      (address user, address vault) = abi.decode(data, (address, address));
      return abi.encode(_hyperCore.readUserVaultEquity(user, vault));
    }

    if (address(this) == WITHDRAWABLE_PRECOMPILE_ADDRESS) {
      address user = abi.decode(data, (address));
      return abi.encode(_hyperCore.readWithdrawable(user));
    }

    if (address(this) == DELEGATIONS_PRECOMPILE_ADDRESS) {
      address user = abi.decode(data, (address));
      return abi.encode(_hyperCore.readDelegations(user));
    }

    if (address(this) == DELEGATOR_SUMMARY_PRECOMPILE_ADDRESS) {
      address user = abi.decode(data, (address));
      return abi.encode(_hyperCore.readDelegatorSummary(user));
    }

    if (address(this) == POSITION_PRECOMPILE_ADDRESS) {
      (address user, uint16 perp) = abi.decode(data, (address, uint16));
      return abi.encode(_hyperCore.readPosition(user, perp));
    }

    revert();
  }
}
