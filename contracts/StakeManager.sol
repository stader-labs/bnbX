//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {IStakeManager} from "./interfaces/IStakeManager.sol";
import {IBnbX} from "./interfaces/IBnbX.sol";
import {ITokenHub} from "./interfaces/ITokenHub.sol";

/**
 * @title Stake Manager Contract
 * @dev Handles Staking of Bnb on BSC
 */
contract StakeManager is
    IStakeManager,
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    uint256 public totalDeposited;
    uint256 public totalUnstaked;
    uint256 public totalOutBuffer;
    uint256 public totalRedelegated;

    address private bnbX;
    address private bcDepositWallet;
    address private tokenHub;

    mapping(uint256 => DelegateRequest) private uuidToDelegateRequestMap;
    uint256 private UUID;

    /**
     * @param _bnbX - Address of BnbX Token on Binance Smart Chain
     * @param _manager - Address of the manager
     * @param _tokenHub - Address of the manager
     * @param _bcDepositWallet - Beck32 encoding of Address of deposit Bot Wallet on Beacon Chain with `0x` prefix
     */
    function initialize(
        address _bnbX,
        address _manager,
        address _tokenHub,
        address _bcDepositWallet
    ) external override initializer {
        __AccessControl_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _manager);

        bnbX = _bnbX;
        tokenHub = _tokenHub;
        bcDepositWallet = _bcDepositWallet;
    }

    /**
     * @dev Allows user to deposit Bnb at BSC and mints BnbX for the user
     * Transfer the user's deposited Bnb to Bot's deposit wallet
     */
    function deposit() external payable override whenNotPaused {
        uint256 amount = msg.value;
        require(amount > 0, "Invalid Amount");

        uint256 amountToMint = convertBnbToBnbX(amount);

        totalDeposited += amount;
        totalUnstaked += amount;

        IBnbX(bnbX).mint(msg.sender, amountToMint);
    }

    function startDelegation()
        external
        override
        whenNotPaused
        returns (uint256)
    {
        require(totalUnstaked > 0, "No more funds to stake");

        uint256 amount = totalUnstaked;
        uuidToDelegateRequestMap[UUID++] = DelegateRequest(
            block.timestamp,
            0,
            amount
        );

        // sends funds to BC
        uint64 expireTime = uint64(block.timestamp + 2 minutes); // As per my transaction at tesnet, this should atleast 2 minutes later
        ITokenHub(tokenHub).transferOut(
            address(0),
            bcDepositWallet,
            amount,
            expireTime
        );

        totalOutBuffer += amount;
        totalUnstaked = 0;
        emit TransferOut(amount);
        return (UUID - 1);
    }

    function completeDelegation(uint256 uuid) external override {
        require(uuidToDelegateRequestMap[uuid].amount > 0, "Invalid UUID");

        uuidToDelegateRequestMap[uuid].endTime = block.timestamp;
        uint256 amount = uuidToDelegateRequestMap[uuid].amount;
        totalOutBuffer -= amount;

        emit Delegate(uuid, amount);
    }

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////            ***Helpers & Utilities***               ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @dev Calculates amount of BnbX for `_amount` Bnb
    function convertBnbToBnbX(uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        uint256 totalShares = IBnbX(bnbX).totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;

        uint256 totalPooledBnb = _getTotalPooledBnb();
        totalPooledBnb = totalPooledBnb == 0 ? 1 : totalPooledBnb;

        uint256 amountInBnbX = (_amount * totalShares) / totalPooledBnb;

        return amountInBnbX;
    }

    function _getTotalPooledBnb() internal view returns (uint256) {
        return (totalDeposited + totalRedelegated);
    }

    function _getTotalStakedBnb() internal view returns (uint256) {
        return (totalDeposited +
            totalRedelegated -
            totalUnstaked -
            totalOutBuffer);
    }

    /**
     * @dev Flips the pause state
     */
    function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused() ? _unpause() : _pause();
    }

    function getContracts() external view override returns (address _bnbX) {
        _bnbX = bnbX;
    }
}
