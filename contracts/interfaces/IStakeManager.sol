//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IStakeManager {
    struct BotDelegateRequest {
        uint256 startTime;
        uint256 endTime;
        uint256 amount;
    }

    struct BotUndelegateRequest {
        uint256 startTime;
        uint256 endTime;
        uint256 amount;
        uint256 amountInBnbX;
    }

    struct WithdrawalRequest {
        uint256 uuid;
        uint256 amountInBnbX;
        uint256 startTime;
    }

    function initialize(
        address _bnbX,
        address _manager,
        address _tokenHub,
        address _bcDepositWallet,
        address _bot
    ) external;

    function deposit() external payable;

    function startDelegation()
        external
        payable
        returns (uint256 _uuid, uint256 _amount);

    function completeDelegation(uint256 _uuid) external;

    function addRestakingRewards(uint256 _amount) external;

    function requestWithdraw(uint256 _amountInBnbX) external;

    function claimWithdraw(uint256 _idx) external;

    function startUndelegation()
        external
        returns (uint256 _uuid, uint256 _amount);

    function undelegationStarted(uint256 _uuid) external;

    function completeUndelegation(uint256 _uuid) external payable;

    function setBotAddress(address _bot) external;

    function setMinDelegateThreshold(uint256 _minDelegateThreshold) external;

    function getTotalPooledBnb() external view returns (uint256);

    function getContracts()
        external
        view
        returns (
            address _bnbX,
            address _tokenHub,
            address _bcDepositWallet,
            address _bot
        );

    function getTokenHubRelayFee() external view returns (uint256);

    function getBotDelegateRequest(uint256 _uuid)
        external
        view
        returns (BotDelegateRequest memory);

    function getBotUndelegateRequest(uint256 _uuid)
        external
        view
        returns (BotUndelegateRequest memory);

    function getUserWithdrawalRequests(address _address)
        external
        view
        returns (WithdrawalRequest[] memory);

    function getUserRequestStatus(address _user, uint256 _idx)
        external
        view
        returns (bool _isClaimable, uint256 _amount);

    function getAllowedWithdrawLimit()
        external
        view
        returns (uint256 _allowedWithdrawBnbXLimit);

    function convertBnbToBnbX(uint256 _amount) external view returns (uint256);

    function convertBnbXToBnb(uint256 _amountInBnbX)
        external
        view
        returns (uint256);

    event Delegate(uint256 _uuid, uint256 _amount);
    event TransferOut(uint256 _amount);
    event SetBotAddress(address indexed _address);
    event RequestWithdraw(address indexed _account, uint256 _amountInBnbX);
    event ClaimWithdrawal(
        address indexed _account,
        uint256 _idx,
        uint256 _amount
    );
    event Undelegate(uint256 _uuid, uint256 _amount);
    event Redelegate(uint256 _amount);
}
