// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

interface IStakeCredit {
    /**
     * @param delegator the address of the delegator
     * @return shares the amount of shares minted
     */
    function delegate(address delegator) external payable returns (uint256 shares);

    /**
     * @return the total amount of BNB staked and reward of the delegator.
     */
    function getPooledBNB(address account) external view returns (uint256);

    /**
     * @return the amount of shares that corresponds to `_bnbAmount` protocol-controlled BNB.
     */
    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);
}
