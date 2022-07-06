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

    uint256 public totalDeposited; // total BNB deposited in contract
    uint256 public totalNotStaked; // total BNB deposited but yet not staked on Beacon Chain
    uint256 public totalOutBuffer; // total BNB in relayer while transfering BSC -> BC
    uint256 public totalDelegatedRewards; // total BNB rewards which are already delegated / staked
    uint256 public totalBnbXToBurn;

    address private bnbX;
    address private bcDepositWallet;
    address private tokenHub;
    address private bot;

    mapping(uint256 => BotDelegateRequest) private uuidToBotDelegateRequestMap;
    mapping(uint256 => BotUndelegateRequest)
        private uuidToBotUndelegateRequestMap;
    mapping(address => WithdrawalRequest[]) private userWithdrawalRequests;

    uint256 private nextDelegateUUID;
    uint256 private nextUndelegateUUID;
    bool private isDelegationPending; // initial default value false
    bool private isUndelegationPending; // initial default value false

    uint256 public minDelegateThreshold;
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
        minDelegateThreshold = 1e18;
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
        totalNotStaked += amount;

        IBnbX(bnbX).mint(msg.sender, amountToMint);
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
        _amount = totalNotStaked - (totalNotStaked % TEN_DECIMALS);

        require(
            relayFeeReceived >= tokenHubRelayFee,
            "Require More Relay Fee, Check getTokenHubRelayFee"
        );
        require(_amount >= minDelegateThreshold, "Insufficient Deposit Amount");

        _uuid = nextDelegateUUID++; // post-increment : assigns the current value first and then increments
        uuidToBotDelegateRequestMap[_uuid] = BotDelegateRequest(
            block.timestamp,
            0,
            _amount
        );
        totalOutBuffer += _amount;
        totalNotStaked -= _amount;

        // sends funds to BC
        uint64 expireTime = uint64(block.timestamp + 2 minutes);
        ITokenHub(tokenHub).transferOut{value: (_amount + relayFeeReceived)}(
            address(0),
            bcDepositWallet,
            _amount,
            expireTime
        );

        isDelegationPending = true;
        emit TransferOut(_amount);
    }

    /**
     * @dev Allows bot to mark the delegateRequest as complete and update the state variables
     * @param _uuid - unique id for which the delgation was completion
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
        totalOutBuffer -= amount;

        isDelegationPending = false;
        emit Delegate(_uuid, amount);
    }

    function increaseTotalDelegatedRewards(uint256 _amount)
        external
        override
        whenNotPaused
        onlyRole(BOT)
    {
        require(_amount > 0, "No fund");
        totalDelegatedRewards += _amount;

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

        IERC20Upgradeable(bnbX).safeTransferFrom(
            msg.sender,
            address(this),
            _amountInBnbX
        );
        uint256 totalShares = IBnbX(bnbX).totalSupply();
        require(
            _amountInBnbX <= (totalShares - totalBnbXToBurn),
            "Not enough BNB to withdraw"
        );

        totalBnbXToBurn += _amountInBnbX;
        userWithdrawalRequests[msg.sender].push(
            WithdrawalRequest(
                nextUndelegateUUID,
                _amountInBnbX,
                block.timestamp
            )
        );

        emit RequestWithdraw(msg.sender, _amountInBnbX);
    }

    function claimWithdraw(uint256 _idx) external override whenNotPaused {
        address user = msg.sender;
        WithdrawalRequest[] storage userRequests = userWithdrawalRequests[user];

        require(_idx < userRequests.length, "Invalid index");

        WithdrawalRequest storage withdrawRequest = userRequests[_idx];
        uint256 uuid = withdrawRequest.uuid;
        uint256 amountInBnbX = withdrawRequest.amountInBnbX;

        BotUndelegateRequest
            storage botUndelegateRequest = uuidToBotUndelegateRequestMap[uuid];
        require(botUndelegateRequest.endTime != 0, "Not able to claim yet");
        userRequests[_idx] = userRequests[userRequests.length - 1];
        userRequests.pop();

        uint256 totalBnbToWithdraw_ = botUndelegateRequest.amount;
        uint256 totalBnbXToBurn_ = botUndelegateRequest.amountInBnbX;
        uint256 amount = (totalBnbToWithdraw_ * amountInBnbX) /
            totalBnbXToBurn_;
        AddressUpgradeable.sendValue(payable(user), amount);

        emit ClaimWithdrawal(user, _idx, amount);
    }

    /**
     * @dev Bot uses this function to communicate regarding start of Undelegation Event
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
        require(!isUndelegationPending, "Previous Undelegation Pending");

        _uuid = nextUndelegateUUID++; // post-increment : assigns the current value first and then increments
        uint256 totalBnbXToBurn_ = totalBnbXToBurn; // To avoid Reentrancy attack
        _amount = convertBnbXToBnb(totalBnbXToBurn_);
        require(_amount > 0, "Insufficient Withdraw Amount");

        uuidToBotUndelegateRequestMap[_uuid] = BotUndelegateRequest(
            block.timestamp,
            0,
            _amount,
            totalBnbXToBurn_
        );

        totalDeposited -= _amount;
        totalBnbXToBurn = 0;

        isUndelegationPending = true;
        IBnbX(bnbX).burn(address(this), totalBnbXToBurn_);
    }

    /**
     * @dev Bot uses this function to send unstaked funds to this contract and
     * communicate regarding completion of Undelegation Event
     * @param _uuid - unique id against which this Undelegation event was logged
     * @notice Use `getBotUndelegateRequest` function to get more details of the logged data
     * @notice send at least the required fund
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
            (botUndelegateRequest.amount > 0) &&
                (botUndelegateRequest.endTime == 0),
            "Invalid UUID"
        );

        uint256 amount = msg.value;
        require(amount >= botUndelegateRequest.amount, "Insufficient Fund");
        botUndelegateRequest.endTime = block.timestamp;

        isUndelegationPending = false;
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

        _revokeRole(BOT, bot);
        bot = _address;
        _setupRole(BOT, _address);

        emit SetBotAddress(_address);
    }

    function setMinDelegateThreshold(uint256 _minDelegateThreshold)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_minDelegateThreshold > 0, "Invalid Threshold");
        minDelegateThreshold = _minDelegateThreshold;
    }

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                 ***Getters***                      ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    function getTotalPooledBnb() public view override returns (uint256) {
        return (totalDeposited + totalDelegatedRewards);
    }

    /**
     * @dev Calculates total Bnb staked on Beacon chain
     */
    function getTotalStakedBnb() public view override returns (uint256) {
        return (totalDeposited +
            totalDelegatedRewards -
            totalNotStaked -
            totalOutBuffer);
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
        uint256 amountInBnbX = withdrawRequest.amountInBnbX;

        BotUndelegateRequest
            storage botUndelegateRequest = uuidToBotUndelegateRequestMap[uuid];

        // bot has triggered startUndelegation
        if (botUndelegateRequest.amount > 0) {
            uint256 totalBnbToWithdraw_ = botUndelegateRequest.amount;
            uint256 totalBnbXToBurn_ = botUndelegateRequest.amountInBnbX;
            _amount = (totalBnbToWithdraw_ * amountInBnbX) / totalBnbXToBurn_;
        }
        // bot has not triggered startUndelegation yet
        else {
            _amount = convertBnbXToBnb(amountInBnbX);
        }
        _isClaimable = (botUndelegateRequest.endTime != 0);
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
