// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/IOperatorRegistry.sol";
import "./interfaces/IStakeHub.sol";
import "./interfaces/IStakeCredit.sol";

/// @title OperatorRegistry
/// @notice OperatorRegistry is the main contract that manages operators.
contract OperatorRegistry is
    IOperatorRegistry,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IStakeHub public constant STAKE_HUB = IStakeHub(0x0000000000000000000000000000000000002002);
    address public override preferredDepositOperator;
    address public override preferredWithdrawalOperator;

    EnumerableSet.AddressSet private operatorSet;

    // @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the OperatorRegistry contract.
    function initialize(address _admin) external initializer {
        if (_admin == address(0)) revert ZeroAddress();

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /// @notice Allows an operator that was already staked on the BNB stake manager
    /// to join the BNBX protocol.
    /// @param _operator Address of the operator.
    function addOperator(address _operator)
        external
        override
        whenNotPaused
        nonReentrant
        whenOperatorDoesNotExist(_operator)
        onlyRole(MANAGER_ROLE)
    {
        if (_operator == address(0)) revert ZeroAddress();

        (uint256 createdTime, bool jailed,) = STAKE_HUB.getValidatorBasicInfo(_operator);
        if (createdTime == 0) revert OperatorNotExisted();
        if (jailed) revert OperatorJailed();

        operatorSet.add(_operator);

        emit AddedOperator(_operator);
    }

    /// @notice Allows to remove an operator from the registry.
    /// @param _operator Address of the operator.
    function removeOperator(address _operator)
        external
        override
        whenNotPaused
        nonReentrant
        whenOperatorDoesExist(_operator)
        onlyRole(MANAGER_ROLE)
    {
        if (_operator == address(0)) revert ZeroAddress();
        if (preferredDepositOperator == _operator) {
            revert OperatorIsPreferredDeposit();
        }
        if (preferredWithdrawalOperator == _operator) {
            revert OperatorIsPreferredWithdrawal();
        }

        if (IStakeCredit(STAKE_HUB.getValidatorCreditContract(_operator)).getPooledBNB(address(this)) != 0) {
            revert DelegationExists();
        }

        operatorSet.remove(_operator);

        emit RemovedOperator(_operator);
    }

    /// @notice Allows to set the preferred operator for deposits.
    /// @param _operator Address of the operator.
    function setPreferredDepositOperator(address _operator)
        external
        override
        whenNotPaused
        nonReentrant
        whenOperatorDoesExist(_operator)
        onlyRole(OPERATOR_ROLE)
    {
        if (_operator == address(0)) revert ZeroAddress();

        preferredDepositOperator = _operator;

        emit SetPreferredDepositOperator(preferredDepositOperator);
    }

    /// @notice Allows to set the preferred operator for withdrawals.
    /// @param _operator Address of the operator.
    function setPreferredWithdrawalOperator(address _operator)
        external
        override
        whenNotPaused
        nonReentrant
        whenOperatorDoesExist(_operator)
        onlyRole(OPERATOR_ROLE)
    {
        if (_operator == address(0)) revert ZeroAddress();

        preferredWithdrawalOperator = _operator;

        emit SetPreferredWithdrawalOperator(preferredWithdrawalOperator);
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

    /// -------------------------------Getters-----------------------------------

    /// @notice Get operator address by its index.
    /// @param _index Operator index.
    /// @return _operator The operator address.
    function getOperatorAt(uint256 _index) external view override returns (address) {
        return operatorSet.at(_index);
    }

    /// @notice Get the total number of operators.
    /// @return The number of operators.
    function getOperatorsLength() external view override returns (uint256) {
        return operatorSet.length();
    }

    /// @notice Check if an operator exists in the registry.
    /// @param _operator Address of the operator.
    /// @return True if the operator exists, false otherwise.
    function operatorExists(address _operator) external view override returns (bool) {
        return operatorSet.contains(_operator);
    }

    /// @notice Return the entire set in an array
    function getOperators() external view override returns (address[] memory) {
        return operatorSet.values();
    }

    /// -------------------------------Modifiers-----------------------------------

    /**
     * @dev Modifier to make a function callable only when the operator exists in the registry.
     * @param _operator The operator address.
     * Requirements:
     *
     * - The operator must exist in the registry.
     */
    modifier whenOperatorDoesExist(address _operator) {
        if (!operatorSet.contains(_operator)) revert OperatorNotExisted();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the operator doesn't exist in the registry.
     * @param _operator The operator address.
     *
     * Requirements:
     *
     * - The operator must not exist in the registry.
     */
    modifier whenOperatorDoesNotExist(address _operator) {
        if (operatorSet.contains(_operator)) revert OperatorExisted();
        _;
    }
}
