// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

struct WithdrawalRequest {
    address user;
    bool processed;
    bool claimed;
    uint256 amountInBnbX;
    uint256 batchId;
}

struct BatchWithdrawalRequest {
    uint256 amountInBnb;
    uint256 amountInBnbX;
    uint256 unlockTime;
    address operator;
    bool isClaimable;
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

    function delegate(
        string calldata _referralId
    ) external payable returns (uint256);
    function requestWithdraw(uint256 _amount) external returns (uint256);
    function claimWithdrawal(uint256 _idx) external returns (uint256);
    function redelegate(
        address _fromOperator,
        address _toOperator,
        uint256 _amount
    ) external;
    function delegateWithoutMinting() external payable;
    function completeUndelegation() external;
    function startUndelegation(uint256 _batchSize, address _operator) external;
    function pause() external;
    function unpause() external;
    function convertBnbToBnbX(uint256 _amount) external view returns (uint256);
    function convertBnbXToBnb(
        uint256 _amountInBnbX
    ) external view returns (uint256);
    function getUserRequests(address _user) external returns (uint256[] memory);

    event Delegated(address indexed _account, uint256 _amount);
    event RequestedWithdrawal(
        address indexed _account,
        uint256 _amountInBnbX
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
    event DelegateReferral(
        address indexed _account,
        uint256 _amountInBnb,
        uint256 _amountInBnbX,
        string _referralId
    );
}
