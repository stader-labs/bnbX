//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {IBnbX} from "./interfaces/IBnbX.sol";

/**
 * @title Stake Manager Contract
 * @dev Handles Staking of Bnb on BSC
 */
contract StakeManager is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    uint256 public totalDeposited;
    uint256 public totalUnstaked;
    uint256 public totalRedelegated;

    address private bnbX;
    address payable private depositWallet;

    /**
     * @param _bnbX - Address of BnbX Token on Binance Smart Chain
     * @param _depositWallet - Address of deposit Bot Wallet which holds Bnb deposits on BSC to be passed to Beacon Chain through Relayer
     */
    function initialize(
        address _bnbX,
        address _manager,
        address payable _depositWallet
    ) external initializer {
        __AccessControl_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _manager);

        bnbX = _bnbX;
        depositWallet = _depositWallet;
    }

    /**
     * @dev Allows user to deposit Bnb at BSC and mints BnbX for the user
     * Transfer the user's deposited Bnb to Bot's deposit wallet
     */
    function deposit() external payable whenNotPaused {
        uint256 amount = msg.value;
        require(amount > 0, "Invalid Amount");

        uint256 amountToMint = convertBnbToBnbX(amount);

        totalDeposited += amount;
        totalUnstaked += amount;
        payable(depositWallet).transfer(amount);

        IBnbX(bnbX).mint(msg.sender, amountToMint);
    }

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////            ***Helpers & Utilities***               ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @dev Calculates amount of BnbX for `_amount` Bnb
    function convertBnbToBnbX(uint256 _amount) public view returns (uint256) {
        uint256 totalShares = IBnbX(bnbX).totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;

        uint256 totalPooledBnb = getTotalPooledBnb();
        totalPooledBnb = totalPooledBnb == 0 ? 1 : totalPooledBnb;

        uint256 amountInBnbX = (_amount * totalShares) / totalPooledBnb;

        return amountInBnbX;
    }

    function getTotalPooledBnb() public view returns (uint256) {
        return (totalDeposited + totalRedelegated);
    }

    /**
     * @dev Flips the pause state
     */
    function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused() ? _unpause() : _pause();
    }

    function getContracts() external view returns (address _bnbX) {
        _bnbX = bnbX;
    }
}
