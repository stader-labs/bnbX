// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

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
    IStakeHub public constant STAKE_HUB =
        IStakeHub(0x0000000000000000000000000000000000002002);
    IOperatorRegistry public OPERATOR_REGISTRY;
    IBnbX public BNBX;

    mapping(address => WithdrawalRequest[]) private userWithdrawalRequests;

    // @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the StakeManagerV2 contract.
    /// @param _operatorRegistry Address of the operator registry contract.
    /// @param _bnbX Address of the BnbX contract.
    function initialize(
        address _operatorRegistry,
        address _bnbX
    ) external initializer {
        if (_operatorRegistry == address(0)) revert ZeroAddress();
        if (_bnbX == address(0)) revert ZeroAddress();

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        OPERATOR_REGISTRY = IOperatorRegistry(_operatorRegistry);
        BNBX = IBnbX(_bnbX);
    }

    /// @notice Delegate BNB to the preferred operator.
    /// @return The amount of BnbX minted.
    function delegate()
        external
        payable
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        if (msg.value < STAKE_HUB.minDelegationBNBChange())
            revert DelegationAmountTooSmall();

        uint256 amountToMint = convertBnbToBnbX(msg.value);
        BNBX.mint(msg.sender, amountToMint);

        address preferredOperatorAddress = OPERATOR_REGISTRY
            .preferredDepositOperator();
        STAKE_HUB.delegate{value: msg.value}(preferredOperatorAddress, true);

        emit Delegated(preferredOperatorAddress, msg.value);
        return amountToMint;
    }

    /// @notice Request to withdraw BnbX and get BNB back.
    /// @param _amount The amount of BnbX to withdraw.
    /// @return The amount of BNB to be received.
    function requestWithdraw(
        uint256 _amount
    ) external override whenNotPaused nonReentrant returns (uint256) {
        if (_amount == 0) revert ZeroAmount();

        uint256 totalAmount2WithdrawInBnb = convertBnbXToBnb(_amount);
        uint256 leftAmount2WithdrawInBnb = totalAmount2WithdrawInBnb;
        BNBX.burn(msg.sender, _amount);

        address preferredOperator = OPERATOR_REGISTRY
            .preferredWithdrawalOperator();
        uint256 operatorsLength = OPERATOR_REGISTRY.getOperatorsLength();
        if (operatorsLength == 0) revert NoOperatorsAvailable();

        uint256 currentIdx = findOperatorIndex(
            preferredOperator,
            operatorsLength
        );

        while (leftAmount2WithdrawInBnb > 0) {
            leftAmount2WithdrawInBnb -= _undelegate(
                OPERATOR_REGISTRY.getOperatorAt(currentIdx),
                leftAmount2WithdrawInBnb
            );

            currentIdx = currentIdx + 1 < operatorsLength ? currentIdx + 1 : 0;
        }

        emit RequestedWithdrawal(
            msg.sender,
            _amount,
            totalAmount2WithdrawInBnb
        );
        return totalAmount2WithdrawInBnb;
    }

    /// @notice Claims the withdrawn BNB after the unbonding period.
    /// @param _idx The index of the withdrawal request.
    /// @return The amount of BNB claimed.
    function claimWithdrawal(
        uint256 _idx
    ) external override whenNotPaused nonReentrant returns (uint256) {
        WithdrawalRequest[] storage userRequests = userWithdrawalRequests[
            msg.sender
        ];
        if (userRequests.length == 0) revert NoWithdrawalRequests();
        if (_idx >= userRequests.length) revert InvalidIndex();

        WithdrawalRequest memory userRequest = userRequests[_idx];
        uint256 amountToClaim = userRequest.bnbAmount;
        if (block.timestamp < userRequest.unlockTime) revert Unbonding();

        STAKE_HUB.claim(userRequest.operator, 0);

        // Swap with the last item and pop it.
        userRequests[_idx] = userRequests[userRequests.length - 1];
        userRequests.pop();

        (bool success, ) = payable(msg.sender).call{value: amountToClaim}("");
        if (!success) revert TransferFailed();

        emit ClaimedWithdrawal(msg.sender, _idx, amountToClaim);
        return amountToClaim;
    }

    /// @notice Redelegate staked BNB from one operator to another.
    /// @param _fromOperator The address of the operator to redelegate from.
    /// @param _toOperator The address of the operator to redelegate to.
    /// @param _amount The amount of BNB to redelegate.
    function redelegate(
        address _fromOperator,
        address _toOperator,
        uint256 _amount
    ) external override nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_fromOperator == address(0)) revert ZeroAddress();
        if (_toOperator == address(0)) revert ZeroAddress();
        if (_fromOperator == _toOperator) revert InvalidIndex();
        if (!OPERATOR_REGISTRY.operatorExists(_fromOperator))
            revert OperatorNotExisted();
        if (!OPERATOR_REGISTRY.operatorExists(_toOperator))
            revert OperatorNotExisted();
        if (_amount < STAKE_HUB.minDelegationBNBChange())
            revert DelegationAmountTooSmall();

        uint256 shares = IStakeCredit(
            STAKE_HUB.getValidatorCreditContract(_fromOperator)
        ).getSharesByPooledBNB(_amount);

        STAKE_HUB.redelegate(_fromOperator, _toOperator, shares, true);

        emit Redelegated(_fromOperator, _toOperator, _amount);
    }

    /// @notice Delegate BNB to the preferred operator without minting BnbX.
    /// @dev This function is useful for boosting staking rewards and for initial
    ///      Fusion hardfork migration without affecting the token supply.
    /// @dev Can only be called by an address with the DEFAULT_ADMIN_ROLE.
    function delegateWithoutMinting()
        external
        payable
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (msg.value < STAKE_HUB.minDelegationBNBChange())
            revert DelegationAmountTooSmall();
        if (BNBX.totalSupply() == 0) revert ZeroAmount();

        address preferredOperatorAddress = OPERATOR_REGISTRY
            .preferredDepositOperator();
        STAKE_HUB.delegate{value: msg.value}(preferredOperatorAddress, true);

        emit Delegated(preferredOperatorAddress, msg.value);
    }

    /// @notice Pause or unpause the contract.
    function togglePause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        paused() ? _unpause() : _pause();
    }

    /// @notice Internal function to undelegate BNB from an operator.
    /// @param _operator The address of the operator.
    /// @param _amount The amount of BNB to undelegate.
    /// @return The amount of BNB actually undelegated.
    function _undelegate(
        address _operator,
        uint256 _amount
    ) internal returns (uint256) {
        address creditContract = STAKE_HUB.getValidatorCreditContract(
            _operator
        );
        uint256 pooledBnb = IStakeCredit(creditContract).getPooledBNB(
            address(this)
        );

        if (pooledBnb == 0) {
            return _amount;
        }

        uint256 amountToWithdrawFromOperator = (pooledBnb <= _amount)
            ? pooledBnb
            : _amount;

        uint256 shares = IStakeCredit(creditContract).getSharesByPooledBNB(
            amountToWithdrawFromOperator
        );
        STAKE_HUB.undelegate(_operator, shares);

        userWithdrawalRequests[msg.sender].push(
            WithdrawalRequest({
                shares: shares,
                bnbAmount: amountToWithdrawFromOperator,
                unlockTime: block.timestamp + STAKE_HUB.unbondPeriod(),
                operator: _operator
            })
        );

        return amountToWithdrawFromOperator;
    }

    function getUserWithdrawalRequests(
        address _user
    ) external view returns (WithdrawalRequest[] memory) {
        return userWithdrawalRequests[_user];
    }

    /// @notice Convert BNB to BnbX.
    /// @param _amount The amount of BNB to convert.
    /// @return The amount of BnbX equivalent.
    function convertBnbToBnbX(
        uint256 _amount
    ) public view override returns (uint256) {
        uint256 totalShares = BNBX.totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;

        uint256 totalPooledBnb = getTotalStakeAcrossAllOperators();
        totalPooledBnb = totalPooledBnb == 0 ? 1 : totalPooledBnb;

        return (_amount * totalShares) / totalPooledBnb;
    }

    /// @notice Convert BnbX to BNB.
    /// @param _amountInBnbX The amount of BnbX to convert.
    /// @return The amount of BNB equivalent.
    function convertBnbXToBnb(
        uint256 _amountInBnbX
    ) public view override returns (uint256) {
        uint256 totalShares = BNBX.totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;

        uint256 totalPooledBnb = getTotalStakeAcrossAllOperators();

        return (_amountInBnbX * totalPooledBnb) / totalShares;
    }

    /// @notice Get the total stake across all operators.
    /// @return The total stake in BNB.
    function getTotalStakeAcrossAllOperators() public view returns (uint256) {
        uint256 totalStake;
        uint256 operatorsLength = OPERATOR_REGISTRY.getOperatorsLength();
        for (uint256 i; i < operatorsLength; ++i) {
            address creditContract = STAKE_HUB.getValidatorCreditContract(
                OPERATOR_REGISTRY.getOperatorAt(i)
            );

            totalStake += IStakeCredit(creditContract).getPooledBNB(
                address(this)
            );
        }
        return totalStake;
    }

    /// @notice Find the index of an operator in the operator registry.
    /// @param operator The address of the operator.
    /// @param operatorsLength The total number of operators.
    /// @return The index of the operator.
    function findOperatorIndex(
        address operator,
        uint256 operatorsLength
    ) internal view returns (uint256) {
        for (uint256 i = 0; i < operatorsLength; ++i) {
            if (operator == OPERATOR_REGISTRY.getOperatorAt(i)) {
                return i;
            }
        }
        return 0;
    }
}
