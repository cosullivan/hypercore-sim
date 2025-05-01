// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

library HyperCoreLib {
  using SafeCast for uint256;

  uint64 public constant KNOWN_TOKEN_USDC = 0;
  uint64 public constant KNOWN_TOKEN_HYPE = 150;

  function scaleWei(uint64 _wei, int8 evmExtraWeiDecimals) internal pure returns (uint256) {
    return
      evmExtraWeiDecimals == 0 ? _wei : evmExtraWeiDecimals > 0
        ? _wei / 10 ** uint8(evmExtraWeiDecimals)
        : _wei * 10 ** uint8(-evmExtraWeiDecimals);
  }

  function toWei(uint256 amount, int8 evmExtraWeiDecimals) internal pure returns (uint64) {
    uint256 _wei = evmExtraWeiDecimals == 0 ? amount : evmExtraWeiDecimals > 0
      ? amount / 10 ** uint8(evmExtraWeiDecimals)
      : amount * 10 ** uint8(-evmExtraWeiDecimals);

    return _wei.toUint64();
  }

  function fromWei(uint64 _wei, int8 evmExtraWeiDecimals) internal pure returns (uint256) {
    return
      evmExtraWeiDecimals == 0 ? _wei : evmExtraWeiDecimals > 0
        ? _wei * 10 ** uint8(evmExtraWeiDecimals)
        : _wei / 10 ** uint8(-evmExtraWeiDecimals);
  }

  function toPerp(uint64 _wei) internal pure returns (uint64) {
    return _wei / 1e2;
  }

  function fromPerp(uint64 usd) internal pure returns (uint64) {
    return usd * 1e2;
  }

  function systemAddress(uint64 token) internal pure returns (address) {
    if (token == KNOWN_TOKEN_HYPE) {
      return 0x2222222222222222222222222222222222222222;
    }
    return address(uint160(address(0x2000000000000000000000000000000000000000)) + token);
  }
}
