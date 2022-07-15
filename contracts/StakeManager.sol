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
 * @dev Handles Staking of BNB on BSC
 */
contract StakeManager is
    IStakeManager,
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public depositsDelegated; // total BNB delegated to validators on Beacon Chain
    uint256 public depositsInContract; // total BNB deposited in contract but not yet transferred to relayer for moving to BC.
    uint256 public depositsBridgingOut; // total BNB in relayer while transfering BSC -> BC
    uint256 public totalBnbToWithdraw;
    uint256 public totalClaimableBnb; // total BNB available to be claimed and resides in contract

    uint256 public nextDelegateUUID;
    uint256 public nextUndelegateUUID;
    uint256 public minDelegateThreshold;
    uint256 public minUndelegateThreshold;

    address private bnbX;
    address private bcDepositWallet;
    address private tokenHub;
    address private bot;

    bool private isDelegationPending; // initial default value false

    mapping(uint256 => BotDelegateRequest) private uuidToBotDelegateRequestMap;
    mapping(uint256 => BotUndelegateRequest)
        private uuidToBotUndelegateRequestMap;
    mapping(address => WithdrawalRequest[]) private userWithdrawalRequests;

    uint256 public constant TEN_DECIMALS = 1e10;
    bytes32 public constant BOT = keccak256("BOT");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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

        require(
            ((_bnbX != address(0)) &&
                (_manager != address(0)) &&
                (_tokenHub != address(0)) &&
                (_bcDepositWallet != address(0)) &&
                (_bot != address(0))),
            "zero address provided"
        );

        _setupRole(DEFAULT_ADMIN_ROLE, _manager);
        _setupRole(BOT, _bot);

        bnbX = _bnbX;
        tokenHub = _tokenHub;
        bcDepositWallet = _bcDepositWallet;
        bot = _bot;
        minDelegateThreshold = 1e18;
        minUndelegateThreshold = 1e18;
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

        uint256 bnbXToMint = convertBnbToBnbX(amount);

        depositsInContract += amount;

        IBnbX(bnbX).mint(msg.sender, bnbXToMint);
    }

    /**
     * @dev Allows bot to transfer users' funds from this contract to botDepositWallet at Beacon Chain
     * @return _uuid - unique id against which this transfer event was logged
     * @return _amount - Amount of funds transferred for staking
     * @notice Use `getBotDelegateRequest` function to get more details of the logged data
     */
    function startDelegation()
        external
        payable
        override
        whenNotPaused
        onlyRole(BOT)
        returns (uint256 _uuid, uint256 _amount)
    {
        require(!isDelegationPending, "Previous Delegation Pending");

        uint256 tokenHubRelayFee = getTokenHubRelayFee();
        uint256 relayFeeReceived = msg.value;
        _amount = depositsInContract - (depositsInContract % TEN_DECIMALS);

        require(
            relayFeeReceived >= tokenHubRelayFee,
            "Require More Relay Fee, Check getTokenHubRelayFee"
        );
        require(_amount >= minDelegateThreshold, "Insufficient Deposit Amount");

        _uuid = nextDelegateUUID++; // post-increment : assigns the current value first and then increments
        uuidToBotDelegateRequestMap[_uuid] = BotDelegateRequest({
            startTime: block.timestamp,
            endTime: 0,
            amount: _amount
        });
        depositsBridgingOut += _amount;
        depositsInContract -= _amount;

        isDelegationPending = true;

        // sends funds to BC // have experimented with 13 hours and it worked
        uint64 expireTime = uint64(block.timestamp + 1 hours);
        ITokenHub(tokenHub).transferOut{value: (_amount + relayFeeReceived)}(
            address(0),
            bcDepositWallet,
            _amount,
            expireTime
        );

        emit TransferOut(_amount);
    }

    /**
     * @dev Allows bot to mark the delegateRequest as complete and update the state variables
     * @param _uuid - unique id for which the delgation was completed
     * @notice Use `getBotDelegateRequest` function to get more details of the logged data
     */
    function completeDelegation(uint256 _uuid)
        external
        override
        whenNotPaused
        onlyRole(BOT)
    {
        require(
            (uuidToBotDelegateRequestMap[_uuid].amount > 0) &&
                (uuidToBotDelegateRequestMap[_uuid].endTime == 0),
            "Invalid UUID"
        );

        uuidToBotDelegateRequestMap[_uuid].endTime = block.timestamp;
        uint256 amount = uuidToBotDelegateRequestMap[_uuid].amount;
        depositsBridgingOut -= amount;
        depositsDelegated += amount;

        isDelegationPending = false;
        emit Delegate(_uuid, amount);
    }

    /**
     * @dev Allows bot to update the contract regarding the rewards
     * @param _amount - Amount of reward
     */
    function addRestakingRewards(uint256 _amount)
        external
        override
        whenNotPaused
        onlyRole(BOT)
    {
        require(_amount > 0, "No reward");
        require(depositsDelegated > 0, "No funds delegated");

        depositsDelegated += _amount;

        emit Redelegate(_amount);
    }

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////              ***Withdraw Flow***                   ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /**
     * @dev Allows user to request for unstake/withdraw funds
     * @param _amountInBnbX - Amount of BnbX to swap for withdraw
     * @notice User must have approved this contract to spend BnbX
     */
    function requestWithdraw(uint256 _amountInBnbX)
        external
        override
        whenNotPaused
    {
        require(_amountInBnbX > 0, "Invalid Amount");

        uint256 bnbToWithdraw = convertBnbXToBnb(_amountInBnbX);
        require(
            bnbToWithdraw <= depositsDelegated,
            "Not enough BNB to withdraw"
        );

        userWithdrawalRequests[msg.sender].push(
            WithdrawalRequest({
                uuid: nextUndelegateUUID,
                amount: bnbToWithdraw,
                startTime: block.timestamp
            })
        );
        depositsDelegated -= bnbToWithdraw;
        totalBnbToWithdraw += bnbToWithdraw;

        IERC20Upgradeable(bnbX).safeTransferFrom(
            msg.sender,
            address(this),
            _amountInBnbX
        );
        IBnbX(bnbX).burn(address(this), _amountInBnbX);

        emit RequestWithdraw(msg.sender, bnbToWithdraw, _amountInBnbX);
    }

    function claimWithdraw(uint256 _idx) external override whenNotPaused {
        address user = msg.sender;
        WithdrawalRequest[] storage userRequests = userWithdrawalRequests[user];

        require(_idx < userRequests.length, "Invalid index");

        WithdrawalRequest storage withdrawRequest = userRequests[_idx];
        uint256 uuid = withdrawRequest.uuid;
        uint256 bnbToWithdraw = withdrawRequest.amount;
        userRequests[_idx] = userRequests[userRequests.length - 1];
        userRequests.pop();

        BotUndelegateRequest
            storage botUndelegateRequest = uuidToBotUndelegateRequestMap[uuid];
        require(botUndelegateRequest.endTime != 0, "Not able to claim yet");

        totalClaimableBnb -= bnbToWithdraw;
        AddressUpgradeable.sendValue(payable(user), bnbToWithdraw);

        emit ClaimWithdrawal(user, _idx, bnbToWithdraw);
    }

    /**
     * @dev Bot uses this function to get amount of BNB to withdraw
     * @return _uuid - unique id against which this Undelegation event was logged
     * @return _amount - Amount of funds required to Unstake
     * @notice Use `getBotUndelegateRequest` function to get more details of the logged data
     */
    function startUndelegation()
        external
        override
        whenNotPaused
        onlyRole(BOT)
        returns (uint256 _uuid, uint256 _amount)
    {
        _uuid = nextUndelegateUUID++; // post-increment : assigns the current value first and then increments
        _amount = totalBnbToWithdraw;
        require(
            _amount >= minUndelegateThreshold,
            "Insufficient Withdraw Amount"
        );

        uuidToBotUndelegateRequestMap[_uuid] = BotUndelegateRequest({
            startTime: 0,
            endTime: 0,
            amount: _amount
        });
        totalBnbToWithdraw = 0;
    }

    /**
     * @dev Allows Bot to communicate regarding start of Undelegation Event at Beacon Chain
     * @param _uuid - unique id against which this Undelegation event was logged
     */
    function undelegationStarted(uint256 _uuid)
        external
        override
        whenNotPaused
        onlyRole(BOT)
    {
        BotUndelegateRequest
            storage botUndelegateRequest = uuidToBotUndelegateRequestMap[_uuid];
        require(
            (botUndelegateRequest.amount > 0) &&
                (botUndelegateRequest.startTime == 0),
            "Invalid UUID"
        );

        botUndelegateRequest.startTime = block.timestamp;
    }

    /**
     * @dev Bot uses this function to send unstaked funds to this contract and
     * communicate regarding completion of Undelegation Event
     * @param _uuid - unique id against which this Undelegation event was logged
     * @notice Use `getBotUndelegateRequest` function to get more details of the logged data
     * @notice send exact amount of BNB
     */
    function completeUndelegation(uint256 _uuid)
        external
        payable
        override
        whenNotPaused
        onlyRole(BOT)
    {
        BotUndelegateRequest
            storage botUndelegateRequest = uuidToBotUndelegateRequestMap[_uuid];
        require(
            (botUndelegateRequest.startTime != 0) &&
                (botUndelegateRequest.endTime == 0),
            "Invalid UUID"
        );

        uint256 amount = msg.value;
        require(amount == botUndelegateRequest.amount, "Insufficient Fund");
        botUndelegateRequest.endTime = block.timestamp;
        totalClaimableBnb += botUndelegateRequest.amount;

        emit Undelegate(_uuid, amount);
    }

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                 ***Setters***                      ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    function setBotAddress(address _address)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(bot != _address, "Old address == new address");
        require(_address != address(0), "zero address provided");

        _revokeRole(BOT, bot);
        bot = _address;
        _setupRole(BOT, _address);

        emit SetBotAddress(_address);
    }

    /// @param _address - Beck32 decoding of Address of deposit Bot Wallet on Beacon Chain with `0x` prefix
    function setBCDepositWallet(address _address)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(bcDepositWallet != _address, "Old address == new address");
        require(_address != address(0), "zero address provided");

        bcDepositWallet = _address;

        emit SetBCDepositWallet(_address);
    }

    function setMinDelegateThreshold(uint256 _minDelegateThreshold)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_minDelegateThreshold > 0, "Invalid Threshold");
        minDelegateThreshold = _minDelegateThreshold;
    }

    function setMinUndelegateThreshold(uint256 _minUndelegateThreshold)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_minUndelegateThreshold > 0, "Invalid Threshold");
        minUndelegateThreshold = _minUndelegateThreshold;
    }

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                 ***Getters***                      ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    function getTotalPooledBnb() public view override returns (uint256) {
        return (depositsDelegated + depositsBridgingOut + depositsInContract);
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

    /**
     * @return relayFee required by TokenHub contract to transfer funds from BSC -> BC
     */
    function getTokenHubRelayFee() public view override returns (uint256) {
        return ITokenHub(tokenHub).relayFee();
    }

    function getBotDelegateRequest(uint256 _uuid)
        external
        view
        override
        returns (BotDelegateRequest memory)
    {
        return uuidToBotDelegateRequestMap[_uuid];
    }

    function getBotUndelegateRequest(uint256 _uuid)
        external
        view
        override
        returns (BotUndelegateRequest memory)
    {
        return uuidToBotUndelegateRequestMap[_uuid];
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

    /**
     * @dev Checks if the withdrawRequest is ready to claim
     * @param _user - Address of the user who raised WithdrawRequest
     * @param _idx - index of request in UserWithdrawls Array
     * @return _isClaimable - if the withdraw is ready to claim yet
     * @return _amount - Amount of BNB user would receive on withdraw claim
     * @notice Use `getUserWithdrawalRequests` to get the userWithdrawlRequests Array
     */
    function getUserRequestStatus(address _user, uint256 _idx)
        external
        view
        override
        returns (bool _isClaimable, uint256 _amount)
    {
        WithdrawalRequest[] storage userRequests = userWithdrawalRequests[
            _user
        ];

        require(_idx < userRequests.length, "Invalid index");

        WithdrawalRequest storage withdrawRequest = userRequests[_idx];
        uint256 uuid = withdrawRequest.uuid;
        _amount = withdrawRequest.amount;

        BotUndelegateRequest
            storage botUndelegateRequest = uuidToBotUndelegateRequestMap[uuid];

        _isClaimable = (botUndelegateRequest.endTime != 0);
    }

    function getBnbXWithdrawLimit()
        external
        view
        override
        returns (uint256 _bnbXWithdrawLimit)
    {
        _bnbXWithdrawLimit = convertBnbToBnbX(depositsDelegated);
    }

    function getExtraBnbInContract()
        external
        view
        override
        returns (uint256 _extraBnb)
    {
        _extraBnb =
            address(this).balance -
            depositsInContract -
            totalClaimableBnb;
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

        uint256 totalPooledBnb = getTotalPooledBnb();
        totalPooledBnb = totalPooledBnb == 0 ? 1 : totalPooledBnb;

        uint256 amountInBnbX = (_amount * totalShares) / totalPooledBnb;

        return amountInBnbX;
    }

    /**
     * @dev Calculates amount of Bnb for `_amountInBnbX` BnbX
     */
    function convertBnbXToBnb(uint256 _amountInBnbX)
        public
        view
        override
        returns (uint256)
    {
        uint256 totalShares = IBnbX(bnbX).totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;

        uint256 totalPooledBnb = getTotalPooledBnb();
        totalPooledBnb = totalPooledBnb == 0 ? 1 : totalPooledBnb;

        uint256 amountInBnb = (_amountInBnbX * totalPooledBnb) / totalShares;

        return amountInBnb;
    }

    /**
     * @dev Flips the pause state
     */
    function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused() ? _unpause() : _pause();
    }
}
