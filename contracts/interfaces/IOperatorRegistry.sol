// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24 <0.9.0;

/// @title IOperatorRegistry
/// @notice Node Operator registry interface
interface IOperatorRegistry {
    error OperatorExisted();
    error OperatorNotExisted();
    error OperatorJailed();
    error OperatorIsPreferredDeposit();
    error OperatorIsPreferredWithdrawal();
    error DelegationExists();
    error ZeroAddress();

    event AddedOperator(address indexed _operator);
    event RemovedOperator(address indexed _operator);
    event SetPreferredDepositOperator(address indexed _operator);
    event SetPreferredWithdrawalOperator(address indexed _operator);

    function preferredDepositOperator() external view returns (address);
    function preferredWithdrawalOperator() external view returns (address);
    function getOperatorAt(uint256) external view returns (address);
    function getOperatorsLength() external view returns (uint256);
    function addOperator(address _operator) external;
    function removeOperator(address _operator) external;
    function setPreferredDepositOperator(address _operator) external;
    function setPreferredWithdrawalOperator(address _operator) external;
    function togglePause() external;
    function operatorExists(address _operator) external view returns (bool);
}
