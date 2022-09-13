// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../../contracts/StakeManager.sol";

contract StakeManagerHarness is StakeManager {
    function getUserWithdrawalRequestLength(address user)
        public
        view
        returns (uint256)
    {
        return getUserWithdrawalRequests(user).length;
    }

    function getUserWithdrawalRequestBnbXAmt(address user, uint256 idx)
        public
        view
        returns (uint256)
    {
        return getUserWithdrawalRequests(user)[idx].amountInBnbX;
    }

    function getNativeTokenBalance(address user) public view returns (uint256) {
        return user.balance;
    }
}
