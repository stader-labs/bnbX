//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IBnbX} from "./interfaces/IBnbX.sol";

contract StakeManager is Initializable {
    uint256 public totalDeposited;
    uint256 public totalUnstaked;
    uint256 public totalRedelegated;

    address private bnbX;
    address payable private depositWallet;

    function initialize(address _bnbX, address payable _depositWallet)
        external
        initializer
    {
        bnbX = _bnbX;
        depositWallet = _depositWallet;
    }

    function poolBnb() external payable {
        require(msg.value > 0, "Invalid Amount");

        totalDeposited += msg.value;
        totalUnstaked += msg.value;
        payable(depositWallet).transfer(msg.value);

        uint256 amountToMint = convertBnbToBnbX(msg.value);

        IBnbX(bnbX).mint(msg.sender, amountToMint);
    }

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////            ***Helpers & Utilities***               ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    function convertBnbToBnbX(uint256 _amount) public view returns (uint256) {
        uint256 totalShares = IERC20Upgradeable(bnbX).totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;

        uint256 totalPooledBnb = getTotalPooledBnb();
        totalPooledBnb = totalPooledBnb == 0 ? 1 : totalPooledBnb;

        uint256 amountInBnbX = (_amount * totalShares) / totalPooledBnb;

        return amountInBnbX;
    }

    function getTotalPooledBnb() public view returns (uint256) {
        return (totalDeposited + totalRedelegated);
    }
}
