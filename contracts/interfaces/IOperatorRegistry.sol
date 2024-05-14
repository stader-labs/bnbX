// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24 < 0.9.0;

/// @title IOperatorRegistry
/// @notice Node Operator registry interface
interface IOperatorRegistry {
    event AddOperator(address indexed _operator);
    event RemoveOperator(address indexed _operator);
    event SetPreferredDepositOperator(address indexed _operator);
    event SetPreferredWithdrawalOperator(address indexed _operator);

    function preferredDepositOperator() external view returns(address);
    function preferredWithdrawalOperator() external view returns(address);
    function getOperator(uint256) external view returns (address);
    function getOperators() external view returns (address[] memory);
    function addOperator(address _operatorId) external;
    function removeOperator(address _operatorId) external;
    function setPreferredDepositOperator(address _operatorId) external;
    function setPreferredWithdrawalOperator(address _operatorId) external;
    function togglePause() external;
}
