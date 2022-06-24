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
    }

    struct WithdrawalRequest {
        uint256 uuid;
        uint256 amount;
        uint256 startTime;
        bool isClaimable;
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

    function increaseTotalRedelegated(uint256 _amount) external;

    function requestWithdraw(uint256 _amount) external;

    function claimWithdraw(uint256 _idx) external;

    function startUndelegation()
        external
        returns (uint256 _uuid, uint256 _amount);

    function completeUndelegation(uint256 _uuid) external payable;

    function setBotAddress(address _bot) external;

    function getTotalPooledBnb() external view returns (uint256);

    function getTotalStakedBnb() external view returns (uint256);

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

    function convertBnbToBnbX(uint256 _amount) external view returns (uint256);

    function convertBnbXToBnb(uint256 _amount) external view returns (uint256);

    event Delegate(uint256 _uuid, uint256 _amount);
    event TransferOut(uint256 _amount);
    event SetBotAddress(address indexed _address);
    event RequestWithdraw(
        address indexed _account,
        uint256 _amountBnbX,
        uint256 _amountBnb
    );
    event ClaimWithdrawal(
        address indexed _account,
        uint256 _idx,
        uint256 _amount
    );
    event Undelegate(uint256 _uuid, uint256 _amount);
    event Redelegate(uint256 _amount);
}
