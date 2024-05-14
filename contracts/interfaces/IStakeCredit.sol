// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IStakeCredit {
    function delegate(address delegator)
        external
        payable
        returns (uint256 shares);
}
