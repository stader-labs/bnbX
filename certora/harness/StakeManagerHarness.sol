// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../../contracts/StakeManager.sol";

contract StakeManagerHarness is StakeManager {
    function getNativeTokenBalance(address user) public view returns (uint256) {
        return user.balance;
    }
}
