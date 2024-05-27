// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24 <0.9.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/IOperatorRegistry.sol";
import "./interfaces/IStakeHub.sol";
import "./interfaces/IStakeCredit.sol";

/// @title OperatorRegistry
/// @notice OperatorRegistry is the main contract that manages operators
contract OperatorRegistry is
    IOperatorRegistry,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    IStakeHub public constant STAKE_HUB =
        IStakeHub(0x0000000000000000000000000000000000002002);
    address public stakeManager;

    address public override preferredDepositOperator;
    address public override preferredWithdrawalOperator;

    EnumerableSet.AddressSet private operatorSet;

    /// @notice Initialize the OperatorRegistry contract.
    function initialize() external initializer {
        __AccessControl_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setStakeManager(address _stakeManager) external {
        stakeManager = _stakeManager;
    }

    /// @notice Allows an operator that was already staked on the bnb stake manager
    /// to join the bnbX protocol.
    /// @param _operator address of the operator.
    function addOperator(
        address _operator
    )
        external
        override
        whenNotPaused
        whenOperatorDoesNotExist(_operator)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        (uint256 createdTime, bool jailed, ) = STAKE_HUB.getValidatorBasicInfo(
            _operator
        );
        if (createdTime == 0) revert OperatorNotExisted();
        if (jailed) revert OperatorJailed();

        operatorSet.add(_operator);

        emit AddOperator(_operator);
    }

    /// @notice Allows to remove an operator from the registry.
    /// @param _operator address of the operator.
    function removeOperator(
        address _operator
    )
        external
        override
        whenNotPaused
        whenOperatorDoesExist(_operator)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (preferredDepositOperator == _operator)
            revert OperatorIsPreferredDeposit();
        if (preferredWithdrawalOperator == _operator)
            revert OperatorIsPreferredWithdrawal();

        if (
            IStakeCredit(STAKE_HUB.getValidatorCreditContract(_operator))
                .getPooledBNB(address(this)) != 0
        ) revert DelegationExists();

        operatorSet.remove(_operator);

        emit RemoveOperator(_operator);
    }

    /// @notice Allows to set the preferred operator for deposits
    /// @param _operator address of the operator.
    function setPreferredDepositOperator(
        address _operator
    )
        external
        override
        whenNotPaused
        whenOperatorDoesExist(_operator)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        preferredDepositOperator = _operator;

        emit SetPreferredDepositOperator(preferredDepositOperator);
    }

    /// @notice Allows to set the preferred operator for withdrawals
    /// @param _operator address of the operator.
    function setPreferredWithdrawalOperator(
        address _operator
    )
        external
        override
        whenNotPaused
        whenOperatorDoesExist(_operator)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        preferredWithdrawalOperator = _operator;

        emit SetPreferredWithdrawalOperator(_operator);
    }

    /// @notice Allows to pause the contract.
    function togglePause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        paused() ? _unpause() : _pause();
    }

    /// -------------------------------Getters-----------------------------------

    /// @notice Get operator address by its index.
    /// @param _index operator index
    /// @return _operator the operator address.
    function getOperatorAt(
        uint256 _index
    ) external view override returns (address) {
        return operatorSet.at(_index);
    }

    function getOperatorsLength() external view override returns (uint256) {
        return operatorSet.length();
    }

    function operatorExists(
        address _operator
    ) external view override returns (bool) {
        return operatorSet.contains(_operator);
    }

    /// -------------------------------Modifiers-----------------------------------

    /**
     * @dev Modifier to make a function callable only when the operator exists in our registry.
     * @param _operator the operator address.
     * Requirements:
     *
     * - The operator must exist in our registry.
     */
    modifier whenOperatorDoesExist(address _operator) {
        if (!operatorSet.contains(_operator)) revert OperatorNotExisted();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the operator doesn't exist in our registry.
     * @param _operator the operator address.
     *
     * Requirements:
     *
     * - The operator must not exist in our registry.
     */
    modifier whenOperatorDoesNotExist(address _operator) {
        if (operatorSet.contains(_operator)) revert OperatorExisted();
        _;
    }
}
