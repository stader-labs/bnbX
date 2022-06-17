//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

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
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public totalDeposited;
    uint256 public totalUnstaked;
    uint256 public totalOutBuffer;
    uint256 public totalRedelegated;
    uint256 public totalBnbToWithdraw;
    uint256 public totalBnbXToBurn;

    address private bnbX;
    address private bcDepositWallet;
    address private tokenHub;
    address private bot;

    mapping(uint256 => BotDelegateRequest) private uuidToBotDelegateRequestMap;
    mapping(uint256 => BotUndelegateRequest)
        private uuidToBotUndelegateRequestMap;
    mapping(address => WithdrawalRequest[]) private userWithdrawalRequests;

    uint256 private delegateUUID;
    uint256 private undelegateUUID;

    uint256 public constant TEN_DECIMALS = 1e10;
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

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////              ***Deposit Flow***                    ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

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
        returns (uint256 _uuid, uint256 _amount)
    {
        uint256 tokenHubRelayFee = getTokenHubRelayFee();
        uint256 relayFeeReceived = msg.value;
        uint256 amount = totalUnstaked - (totalUnstaked % TEN_DECIMALS);

        require(
            relayFeeReceived >= tokenHubRelayFee,
            "Require More Relay Fee, Check getTokenHubRelayFee"
        );
        require(amount > 0, "No more funds to stake");

        uuidToBotDelegateRequestMap[delegateUUID++] = BotDelegateRequest(
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

        _uuid = delegateUUID - 1;
        _amount = amount;
    }

    function completeDelegation(uint256 uuid)
        external
        override
        whenNotPaused
        onlyRole(BOT)
    {
        require(
            (uuidToBotDelegateRequestMap[uuid].amount > 0) &&
                (uuidToBotDelegateRequestMap[uuid].endTime == 0),
            "Invalid UUID"
        );

        uuidToBotDelegateRequestMap[uuid].endTime = block.timestamp;
        uint256 amount = uuidToBotDelegateRequestMap[uuid].amount;
        totalOutBuffer -= amount;

        emit Delegate(uuid, amount);
    }

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////              ***Withdraw Flow***                   ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    function requestWithdraw(uint256 _amount) external override whenNotPaused {
        require(_amount > 0, "Invalid Amount");
        uint256 amountInBnb = convertBnbXToBnb(_amount);

        IERC20Upgradeable(bnbX).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        uint256 totalPooledBnb = _getTotalPooledBnb();
        require(amountInBnb <= totalPooledBnb, "Not enough BNB to withdraw");

        totalBnbToWithdraw += amountInBnb;
        totalBnbXToBurn += _amount;
        userWithdrawalRequests[msg.sender].push(
            WithdrawalRequest(undelegateUUID, amountInBnb)
        );

        emit RequestWithdraw(msg.sender, _amount, amountInBnb);
    }

    function claimWithdraw(uint256 _idx) external override whenNotPaused {
        address user = msg.sender;
        WithdrawalRequest[] storage userRequests = userWithdrawalRequests[user];

        require(_idx < userRequests.length, "Invalid index");

        WithdrawalRequest memory withdrawRequest = userRequests[_idx];
        uint256 uuid = withdrawRequest.uuid;
        uint256 amount = withdrawRequest.amount;

        require(
            uuidToBotUndelegateRequestMap[uuid].endTime != 0,
            "Not able to claim yet"
        );

        userRequests[_idx] = userRequests[userRequests.length - 1];
        userRequests.pop();
        AddressUpgradeable.sendValue(payable(user), amount);

        emit ClaimWithdrawal(user, _idx, withdrawRequest.amount);
    }

    function startUndelegation()
        external
        override
        whenNotPaused
        onlyRole(BOT)
        returns (uint256 _uuid, uint256 _amount)
    {
        require(totalBnbToWithdraw > 0, "No Request to withdraw");

        _uuid = undelegateUUID++;
        _amount = totalBnbToWithdraw;
        uuidToBotUndelegateRequestMap[_uuid] = BotUndelegateRequest(
            block.timestamp,
            0,
            _amount
        );

        totalDeposited -= _amount;
        uint256 bnbXToBurn = totalBnbXToBurn; // To avoid Reentrancy attack
        totalBnbXToBurn = 0;
        totalBnbToWithdraw = 0;

        IBnbX(bnbX).burn(address(this), bnbXToBurn);
    }

    function completeUndelegation(uint256 _uuid)
        external
        payable
        override
        whenNotPaused
        onlyRole(BOT)
    {
        require(
            (uuidToBotUndelegateRequestMap[_uuid].amount > 0) &&
                (uuidToBotUndelegateRequestMap[_uuid].endTime == 0),
            "Invalid UUID"
        );

        uint256 amount = msg.value;
        require(
            amount == uuidToBotUndelegateRequestMap[_uuid].amount,
            "Incorrect Amount of Fund"
        );
        uuidToBotUndelegateRequestMap[_uuid].endTime = block.timestamp;

        emit Undelegate(_uuid, amount);
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

    function convertBnbXToBnb(uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        uint256 totalShares = IBnbX(bnbX).totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;

        uint256 totalPooledBnb = _getTotalPooledBnb();
        totalPooledBnb = totalPooledBnb == 0 ? 1 : totalPooledBnb;

        uint256 amountInBnb = (_amount * totalPooledBnb) / totalShares;

        return amountInBnb;
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

    /**
     * @dev Retrieves all withdrawal requests initiated by the given address
     * @param _address - Address of an user
     * @return userWithdrawalRequests array of user withdrawal requests
     */
    function getUserWithdrawalRequests(address _address)
        external
        view
        override
        returns (WithdrawalRequest[] memory)
    {
        return userWithdrawalRequests[_address];
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
