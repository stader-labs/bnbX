//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

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
    address private bot;

    mapping(uint256 => DelegateRequest) private uuidToDelegateRequestMap;
    uint256 private UUID;

    bytes32 public constant BOT = keccak256("BOT");

    /**
     * @param _bnbX - Address of BnbX Token on Binance Smart Chain
     * @param _manager - Address of the manager
     * @param _tokenHub - Address of the manager
     * @param _bcDepositWallet - Beck32 decoding of Address of deposit Bot Wallet on Beacon Chain with `0x` prefix
     * @param _bot - Address of the Bot
     */
    function initialize(
        address _bnbX,
        address _manager,
        address _tokenHub,
        address _bcDepositWallet,
        address _bot
    ) external override initializer {
        __AccessControl_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _manager);
        _setupRole(BOT, _bot);

        bnbX = _bnbX;
        tokenHub = _tokenHub;
        bcDepositWallet = _bcDepositWallet;
        bot = _bot;
    }

    /**
     * @dev Allows user to deposit Bnb at BSC and mints BnbX for the user
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
        payable
        override
        whenNotPaused
        onlyRole(BOT)
        returns (uint256)
    {
        uint256 tokenHubRelayFee = getTokenHubRelayFee();
        uint256 relayFeeReceived = msg.value;
        uint256 amount = totalUnstaked;

        require(
            relayFeeReceived >= tokenHubRelayFee,
            "Require More Relay Fee, Check getTokenHubRelayFee"
        );
        require(amount > 0, "No more funds to stake");

        uuidToDelegateRequestMap[UUID++] = DelegateRequest(
            block.timestamp,
            0,
            amount
        );
        totalOutBuffer += amount;
        totalUnstaked -= amount;

        // sends funds to BC
        uint64 expireTime = uint64(block.timestamp + 2 minutes);
        ITokenHub(tokenHub).transferOut{value: (amount + relayFeeReceived)}(
            address(0),
            bcDepositWallet,
            amount,
            expireTime
        );

        emit TransferOut(amount);
        return (UUID - 1);
    }

    function completeDelegation(uint256 uuid)
        external
        override
        whenNotPaused
        onlyRole(BOT)
    {
        require(
            (uuidToDelegateRequestMap[uuid].amount > 0) &&
                (uuidToDelegateRequestMap[uuid].endTime == 0),
            "Invalid UUID"
        );

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

    /**
     * @dev Calculates amount of BnbX for `_amount` Bnb
     */
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

    function getContracts()
        external
        view
        override
        returns (
            address _bnbX,
            address _tokenHub,
            address _bcDepositWallet,
            address _bot
        )
    {
        _bnbX = bnbX;
        _tokenHub = tokenHub;
        _bcDepositWallet = bcDepositWallet;
        _bot = bot;
    }

    function getTokenHubRelayFee() public view override returns (uint256) {
        return ITokenHub(tokenHub).relayFee();
    }

    function setBotAddress(address _address)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(bot != _address, "Old address == new address");

        _revokeRole(BOT, bot);
        bot = _address;
        _setupRole(BOT, _address);

        emit SetBotAddress(_address);
    }
}
