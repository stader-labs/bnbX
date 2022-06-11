//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// pragma solidity 0.6.4; // this was actual solidity version

/// @title binance TokenHub interface
/// @dev Helps in cross-chain transfers
interface ITokenHub {
    function relayFee() external view returns (uint256);

    function transferOut(
        address contractAddr,
        address recipient,
        uint256 amount,
        uint64 expireTime
    ) external payable returns (bool);
}
