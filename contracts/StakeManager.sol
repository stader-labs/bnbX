//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "hardhat/console.sol";

// import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract StakeManager {
    // using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public totalDeposited;
    uint256 public totalUnstaked;

    address payable private botDepositWallet;

    function poolBNB() public payable {
        require(msg.value > 0, "Invalid Amount");
        payable(botDepositWallet).transfer(msg.value);
        totalDeposited += msg.value;
        totalUnstaked += msg.value;
    }
}
