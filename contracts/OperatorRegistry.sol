// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24 < 0.9.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IOperatorRegistry.sol";
import "./interfaces/IStakeHub.sol";

/// @title OperatorRegistry
/// @notice OperatorRegistry is the main contract that manages operators
contract OperatorRegistry is
    IOperatorRegistry,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    IStakeHub public STAKEHUB;
    address public BNBX;

    address public override preferredDepositOperator;
    address public override preferredWithdrawalOperator;
    mapping(address => bool) public operatorExists;

    address[] private operators;

    /// @notice Initialize the OperatorRegistry contract.
    /// @param _stakeHub address of the stake hub contract.
    /// @param _bnbX address of the bnbX contract.
    /// @param _manager address of the manager.
    function initialize(
        address _stakeHub,
        address _bnbX,
        address _manager
    ) external initializer {
        __AccessControl_init();
        __Pausable_init();

        STAKEHUB = IStakeHub(_stakeHub);
        BNBX = _bnbX;

        _setupRole(DEFAULT_ADMIN_ROLE, _manager);
    }

    /// @notice Allows an operator that was already staked on the bnb stake manager
    /// to join the bnbX protocol.
    /// @param _operator address of the operator.
    function addOperator(address _operator)
        external
        override
        whenNotPaused
        whenOperatorDoesNotExist(_operator)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        (uint256 createdTime, bool jailed, ) = STAKEHUB.getValidatorBasicInfo(_operator);
        require(
            createdTime > 0,
            "Operator is not registered on STAKEHUB"
        );
        require(
            jailed == true,
            "Operator is jailed"
        );

        operators.push(_operator);
        operatorExists[_operator] = true;

        emit AddOperator(_operator);
    }

    /// @notice Allows to remove an operator from the registry.
    /// @param _operator address of the operator.
    function removeOperator(address _operator)
        external
        override
        whenNotPaused
        whenOperatorDoesExist(_operator)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            preferredDepositOperator != _operator,
            "Can't remove a preferred operator for deposits"
        );
        require(
            preferredWithdrawalOperator != _operator,
            "Can't remove a preferred operator for withdrawals"
        );

        // TODO: Check remaining shares
        // TODO: Migrate remaining shares

        delete operatorExists[_operator];

        emit RemoveOperator(_operator);
    }

    /// @notice Allows to set the preferred operator for deposits
    /// @param _operator address of the operator.
    function setPreferredDepositOperator(address _operator)
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
    function setPreferredWithdrawalOperator(address _operator)
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
    function getOperator(uint256 _index)
        external
        view
        override
        returns (address)
    {
        return operators[_index];
    }

    /// @notice Get operators.
    /// @return _operators the operators.
    function getOperators() external view override returns (address[] memory) {
        return operators;
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
        require(
            operatorExists[_operator] == true,
            "Operator doesn't exist in our registry"
        );
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
        require(
            operatorExists[_operator] == false,
            "Operator already exists in our registry"
        );
        _;
    }
}
