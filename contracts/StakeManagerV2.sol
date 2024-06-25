// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/IStakeHub.sol";
import "./interfaces/IBnbX.sol";
import "./interfaces/IOperatorRegistry.sol";
import "./interfaces/IStakeManagerV2.sol";
import "./interfaces/IStakeCredit.sol";

/// @title StakeManagerV2
/// @notice This contract manages staking, withdrawal, and re-delegation of BNB through a stake hub and operator registry.
contract StakeManagerV2 is
    IStakeManagerV2,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IBnbX;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IStakeHub public constant STAKE_HUB = IStakeHub(0x0000000000000000000000000000000000002002);
    IOperatorRegistry public OPERATOR_REGISTRY;
    IBnbX public BNBX;

    address public staderTreasury;
    uint256 public totalDelegated;
    uint256 public feeBps;
    uint256 public maxExchangeRateSlippageBps;
    uint256 public maxActiveRequestsPerUser;
    uint256 public firstUnprocessedUserIndex;
    uint256 public firstUnbondingBatchIndex;

    WithdrawalRequest[] private withdrawalRequests;
    BatchWithdrawalRequest[] private batchWithdrawalRequests;
    mapping(address => uint256[]) private userRequests;

    // @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the StakeManagerV2 contract.
    /// @param _operatorRegistry Address of the operator registry contract.
    /// @param _bnbX Address of the BnbX contract.
    function initialize(
        address _admin,
        address _operatorRegistry,
        address _bnbX,
        address _staderTreasury,
        uint256 _feeBps
    )
        external
        initializer
    {
        if (_admin == address(0)) revert ZeroAddress();
        if (_operatorRegistry == address(0)) revert ZeroAddress();
        if (_bnbX == address(0)) revert ZeroAddress();
        if (_staderTreasury == address(0)) revert ZeroAddress();

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);

        OPERATOR_REGISTRY = IOperatorRegistry(_operatorRegistry);
        BNBX = IBnbX(_bnbX);
        staderTreasury = _staderTreasury;
        feeBps = _feeBps;
    }

    /*//////////////////////////////////////////////////////////////
                            user interactions
    //////////////////////////////////////////////////////////////*/

    /// @notice Delegate BNB to the preferred operator.
    /// @param _referralId referral id of KOL
    /// @return The amount of BnbX minted.
    function delegate(string calldata _referralId)
        external
        payable
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        uint256 amountToMint = convertBnbToBnbX(msg.value);
        _delegate();
        BNBX.mint(msg.sender, amountToMint);

        emit DelegateReferral(msg.sender, msg.value, amountToMint, _referralId);
        return amountToMint;
    }

    /// @notice Request to withdraw BnbX and get BNB back.
    /// @param _amount The amount of BnbX to withdraw.
    /// @return The index of the withdrawal request.
    function requestWithdraw(uint256 _amount) external override whenNotPaused nonReentrant returns (uint256) {
        if (_amount == 0) revert ZeroAmount();
        if (userRequests[msg.sender].length >= maxActiveRequestsPerUser) revert MaxLimitReached();

        withdrawalRequests.push(
            WithdrawalRequest({ user: msg.sender, amountInBnbX: _amount, claimed: false, batchId: 0, processed: false })
        );

        uint256 requestId = withdrawalRequests.length - 1;
        userRequests[msg.sender].push(requestId);

        BNBX.safeTransferFrom(msg.sender, address(this), _amount);
        emit RequestedWithdrawal(msg.sender, _amount);

        return requestId;
    }

    /// @notice Claim the BNB from a withdrawal request.
    /// @param _idx The index of the withdrawal request.
    /// @return The amount of BNB claimed.
    function claimWithdrawal(uint256 _idx) external override whenNotPaused nonReentrant returns (uint256) {
        WithdrawalRequest storage request = _extractRequest(msg.sender, _idx);
        if (request.claimed) revert AlreadyClaimed();

        BatchWithdrawalRequest memory batchRequest = batchWithdrawalRequests[request.batchId];
        if (!batchRequest.isClaimable) revert Unbonding();

        request.claimed = true;
        uint256 amountInBnb = (batchRequest.amountInBnb * request.amountInBnbX) / batchRequest.amountInBnbX;

        (bool success,) = payable(msg.sender).call{ value: amountInBnb }("");
        if (!success) revert TransferFailed();

        emit ClaimedWithdrawal(msg.sender, _idx, amountInBnb);
        return amountInBnb;
    }

    /// @notice Start the batch undelegation process.
    /// @param _batchSize The size of the batch.
    /// @param _operator The address of the operator to undelegate from.
    function startBatchUndelegation(
        uint256 _batchSize,
        address _operator
    )
        external
        override
        whenNotPaused
        nonReentrant
        onlyRole(OPERATOR_ROLE)
    {
        if (_operator == address(0)) {
            // if operator is not provided, use preferred operator
            _operator = OPERATOR_REGISTRY.preferredWithdrawalOperator();
        }
        if (!OPERATOR_REGISTRY.operatorExists(_operator)) {
            revert OperatorNotExisted();
        }

        address creditContract = STAKE_HUB.getValidatorCreditContract(_operator);
        uint256 amountInBnbXToBurn = _computeBnbXToBurn(_batchSize, creditContract);
        uint256 amountToWithdrawFromOperator = convertBnbXToBnb(amountInBnbXToBurn);
        totalDelegated -= amountToWithdrawFromOperator;

        batchWithdrawalRequests.push(
            BatchWithdrawalRequest({
                amountInBnb: amountToWithdrawFromOperator,
                amountInBnbX: amountInBnbXToBurn,
                unlockTime: block.timestamp + STAKE_HUB.unbondPeriod(),
                operator: _operator,
                isClaimable: false
            })
        );

        uint256 shares = IStakeCredit(creditContract).getSharesByPooledBNB(amountToWithdrawFromOperator);
        BNBX.burn(address(this), amountInBnbXToBurn);
        STAKE_HUB.undelegate(_operator, shares);

        emit StartedBatchUndelegation(_operator, amountToWithdrawFromOperator, amountInBnbXToBurn);
    }

    /// @notice Complete the undelegation process.
    /// @dev This function can only be called by an address with the OPERATOR_ROLE.
    function completeBatchUndelegation() external override whenNotPaused nonReentrant {
        BatchWithdrawalRequest storage batchRequest = batchWithdrawalRequests[firstUnbondingBatchIndex];
        if (batchRequest.unlockTime > block.timestamp) revert Unbonding();

        batchRequest.isClaimable = true;
        firstUnbondingBatchIndex++;
        STAKE_HUB.claim(batchRequest.operator, 1); // claims 1 request

        emit CompletedBatchUndelegation(batchRequest.operator, batchRequest.amountInBnb);
    }

    /// @notice Redelegate staked BNB from one operator to another.
    /// @param _fromOperator The address of the operator to redelegate from.
    /// @param _toOperator The address of the operator to redelegate to.
    /// @param _amount The amount of BNB to redelegate.
    /// @dev redelegate has a fee associated with it. This fee will be consumed from TVL. See fn:getRedelegationFee()
    /// @dev redelegate doesn't have a waiting period
    function redelegate(
        address _fromOperator,
        address _toOperator,
        uint256 _amount
    )
        external
        override
        nonReentrant
        onlyRole(MANAGER_ROLE)
    {
        if (!OPERATOR_REGISTRY.operatorExists(_fromOperator)) {
            revert OperatorNotExisted();
        }
        if (!OPERATOR_REGISTRY.operatorExists(_toOperator)) {
            revert OperatorNotExisted();
        }

        uint256 shares = IStakeCredit(STAKE_HUB.getValidatorCreditContract(_fromOperator)).getSharesByPooledBNB(_amount);
        STAKE_HUB.redelegate(_fromOperator, _toOperator, shares, true);

        emit Redelegated(_fromOperator, _toOperator, _amount);
    }

    /// @notice Update the Exchange Rate
    function updateER() external override nonReentrant whenNotPaused {
        uint256 currentER = convertBnbXToBnb(1 ether);
        _updateER();
        _checkIfNewExchangeRateWithinLimits(currentER);
    }

    /// @notice force update the exchange rate
    function forceUpdateER() external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateER();
    }

    /// @notice Delegate BNB to the preferred operator without minting BnbX.
    /// @dev This function is useful for boosting staking rewards and,
    ///      for initial Fusion hardfork migration without affecting the token supply.
    /// @dev Can only be called by an address with the MANAGER_ROLE.
    function delegateWithoutMinting() external payable override onlyRole(MANAGER_ROLE) {
        if (BNBX.totalSupply() == 0) revert ZeroAmount();

        _delegate();
    }

    /**
     * @dev Triggers stopped state.
     * Contract must not be paused
     */
    function pause() external override onlyRole(MANAGER_ROLE) {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     * Contract must be paused
     */
    function unpause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                                setters
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the address of the Stader Treasury.
    /// @param _staderTreasury The new address of the Stader Treasury.
    function setStaderTreasury(address _staderTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_staderTreasury != address(0)) revert ZeroAddress();
        staderTreasury = _staderTreasury;
        emit SetStaderTreasury(_staderTreasury);
    }

    function setFeeBps(uint256 _feeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feeBps > 5000) revert MaxLimitReached();
        feeBps = _feeBps;
        emit SetFeeBps(_feeBps);
    }

    /// @notice set maxActiveRequestsPerUser
    function setMaxActiveRequestsPerUser(uint256 _maxActiveRequestsPerUser) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxActiveRequestsPerUser = _maxActiveRequestsPerUser;
        emit SetMaxActiveRequestsPerUser(_maxActiveRequestsPerUser);
    }

    /// @notice set maxExchangeRateSlippageBps
    function setMaxExchangeRateSlippageBps(uint256 _maxExchangeRateSlippageBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxExchangeRateSlippageBps = _maxExchangeRateSlippageBps;
        emit SetMaxExchangeRateSlippageBps(_maxExchangeRateSlippageBps);
    }

    /*//////////////////////////////////////////////////////////////
                        internal functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Delegate BNB to the preferred operator.
    function _delegate() internal {
        address preferredOperatorAddress = OPERATOR_REGISTRY.preferredDepositOperator();
        totalDelegated += msg.value;

        STAKE_HUB.delegate{ value: msg.value }(preferredOperatorAddress, true);
        emit Delegated(preferredOperatorAddress, msg.value);
    }

    /// @dev extracts the withdrawal request and removes from userRequests
    function _extractRequest(address _user, uint256 _idx) internal returns (WithdrawalRequest storage request) {
        uint256[] storage userRequestsStorage = userRequests[_user];
        // any change to userRequestsStorage will also be reflected in userRequests[_user]
        // see ref: https://docs.soliditylang.org/en/v0.8.25/types.html#data-location-and-assignment-behavior
        uint256 numUserRequests = userRequestsStorage.length;
        if (numUserRequests == 0) revert NoWithdrawalRequests();
        if (_idx >= numUserRequests) revert InvalidIndex();

        uint256 requestId = userRequestsStorage[_idx];
        userRequestsStorage[_idx] = userRequestsStorage[numUserRequests - 1];
        userRequestsStorage.pop();
        return withdrawalRequests[requestId];
    }

    /// @dev internal fn to update the exchange rate
    function _updateER() internal {
        uint256 totalPooledBnb = getActualStakeAcrossAllOperators();
        _mintFees(totalPooledBnb);
        totalDelegated = totalPooledBnb;
    }

    /// @dev internal fn to mint the fees to the stader treasury
    function _mintFees(uint256 _totalPooledBnb) internal {
        if (_totalPooledBnb <= totalDelegated) return;

        uint256 feeInBnb = ((_totalPooledBnb - totalDelegated) * feeBps) / 10_000;
        uint256 amountToMint = convertBnbToBnbX(feeInBnb);
        BNBX.mint(staderTreasury, amountToMint);
    }

    /// @dev internal fn to check if new exchange rate is within limits
    function _checkIfNewExchangeRateWithinLimits(uint256 currentER) internal {
        uint256 maxAllowableDelta = maxExchangeRateSlippageBps * currentER / 10_000;
        uint256 newER = convertBnbXToBnb(1 ether);
        if ((newER > currentER + maxAllowableDelta) || (newER < currentER - maxAllowableDelta)) {
            revert ExchangeRateOutOfBounds(currentER, maxAllowableDelta, newER);
        }
        emit ExchangeRateUpdated(currentER, newER);
    }

    /// @dev internal fn to compute the amount of BNBX to burn for a batch
    function _computeBnbXToBurn(
        uint256 _batchSize,
        address _creditContract
    )
        internal
        returns (uint256 amountInBnbXToBurn)
    {
        uint256 pooledBnb = IStakeCredit(_creditContract).getPooledBNB(address(this));

        uint256 cummulativeBnbXToBurn = amountInBnbXToBurn + withdrawalRequests[firstUnprocessedUserIndex].amountInBnbX;
        uint256 cummulativeBnbToWithdraw = convertBnbXToBnb(cummulativeBnbXToBurn);
        uint256 processedCount;

        while (
            (processedCount < _batchSize) && (firstUnprocessedUserIndex < withdrawalRequests.length)
                && (cummulativeBnbToWithdraw >= pooledBnb)
        ) {
            amountInBnbXToBurn = cummulativeBnbXToBurn;
            withdrawalRequests[firstUnprocessedUserIndex].processed = true;
            withdrawalRequests[firstUnprocessedUserIndex].batchId = batchWithdrawalRequests.length;
            processedCount++;
            firstUnprocessedUserIndex++;
            // below line won't end up in infinite loop, these checks will stop it
            // (processedCount < _batchSize) && (firstUnprocessedUserIndex < withdrawalRequests.length)
            cummulativeBnbXToBurn += withdrawalRequests[firstUnprocessedUserIndex].amountInBnbX;
            cummulativeBnbToWithdraw = convertBnbXToBnb(cummulativeBnbXToBurn);
        }

        if (amountInBnbXToBurn == 0) revert NoWithdrawalRequests();
    }

    /*//////////////////////////////////////////////////////////////
                            getters
    //////////////////////////////////////////////////////////////*/

    /// @notice Get withdrawal requests of a user
    function getUserRequests(address _user) external view returns (uint256[] memory) {
        return userRequests[_user];
    }

    /// @notice Get the fee associated with a redelegation.
    /// @param _amount The amount of BNB to redelegate.
    /// @return The fee associated with the redelegation.
    function getRedelegationFee(uint256 _amount) external view returns (uint256) {
        return (_amount * STAKE_HUB.redelegateFeeRate()) / STAKE_HUB.REDELEGATE_FEE_RATE_BASE();
    }

    /// @notice Convert BNB to BnbX.
    /// @param _amount The amount of BNB to convert.
    /// @return The amount of BnbX equivalent.
    function convertBnbToBnbX(uint256 _amount) public view override returns (uint256) {
        uint256 totalShares = BNBX.totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;
        uint256 totalDelegated_ = totalDelegated == 0 ? 1 : totalDelegated;

        return (_amount * totalShares) / totalDelegated_;
    }

    /// @notice Convert BnbX to BNB.
    /// @param _amountInBnbX The amount of BnbX to convert.
    /// @return The amount of BNB equivalent.
    function convertBnbXToBnb(uint256 _amountInBnbX) public view override returns (uint256) {
        uint256 totalShares = BNBX.totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;

        return (_amountInBnbX * totalDelegated) / totalShares;
    }

    /// @notice Get the total stake across all operators.
    /// @dev This is not stale
    /// @dev gas expensive: use cautiously
    /// @return The total stake in BNB.
    function getActualStakeAcrossAllOperators() public view returns (uint256) {
        uint256 totalStake;
        uint256 operatorsLength = OPERATOR_REGISTRY.getOperatorsLength();
        address[] memory operators = OPERATOR_REGISTRY.getOperators();

        for (uint256 i; i < operatorsLength;) {
            address creditContract = STAKE_HUB.getValidatorCreditContract(operators[i]);
            totalStake += IStakeCredit(creditContract).getPooledBNB(address(this));
            unchecked {
                ++i;
            }
        }
        return totalStake;
    }
}
