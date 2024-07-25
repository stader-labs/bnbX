// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

library ProtocolConstants {
    // addresses
    address public constant STAKE_HUB_ADDR = 0x0000000000000000000000000000000000002002;

    // values
    uint256 public constant MAX_NEGLIGIBLE_AMOUNT = 1e15;
    uint256 public constant MAX_ALLOWED_FEE_BPS = 5000;
    uint256 public constant BPS_DENOM = 10_000;
}
