// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24 <0.9.0;

struct WithdrawalRequest {
    uint256 shares;
    uint256 bnbAmount;
    uint256 unlockTime;
    address operator;
}

interface IStakeManagerV2 {
    error TransferFailed();
    error DelegationAmountTooSmall();
    error OperatorNotExisted();
    error ZeroAmount();
    error ZeroAddress();
    error Unbonding();
    error NoOperatorsAvailable();
    error NoWithdrawalRequests();
    error InvalidIndex();

    function delegate() external payable returns (uint256);
    function requestWithdraw(uint256 _amount) external returns (uint256);
    function claimWithdrawal(uint256 _idx) external returns (uint256);
    function redelegate(
        address _fromOperator,
        address _toOperator,
        uint256 _amount
    ) external;
    function togglePause() external;
    function delegateWithoutMinting() external payable;
    function setOperatorRegistry(address _operatorRegistry) external;
    function setBnbX(address _bnbX) external;
    function convertBnbToBnbX(uint256 _amount) external view returns (uint256);
    function convertBnbXToBnb(
        uint256 _amountInBnbX
    ) external view returns (uint256);
    function getUserWithdrawalRequests(
        address _user
    ) external returns (WithdrawalRequest[] memory);

    event Delegated(address indexed _account, uint256 _amount);
    event RequestedWithdrawal(
        address indexed _account,
        uint256 _amountInBnbX,
        uint256 _amountInBnb
    );
    event ClaimedWithdrawal(
        address indexed _account,
        uint256 _index,
        uint256 _amountInBnb
    );
    event Redelegated(
        address indexed _fromOperator,
        address indexed _toOperator,
        uint256 _amountInBnb
    );
    event OperatorRegistryUpdated(address indexed _operatorRegistry);
    event BnbXUpdated(address indexed _bnbx);
}
