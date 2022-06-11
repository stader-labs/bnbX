//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IStakeManager {
    struct DelegateRequest {
        uint256 startTime;
        uint256 endTime;
        uint256 amount;
    }

    function initialize(
        address _bnbX,
        address _manager,
        address _tokenHub,
        address _bcDepositWallet,
        address _bot
    ) external;

    function deposit() external payable;

    function startDelegation() external payable returns (uint256);

    function completeDelegation(uint256 uuid) external;

    function convertBnbToBnbX(uint256 _amount) external view returns (uint256);

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

    function setBotAddress(address _bot) external;

    event Delegate(uint256 uuid, uint256 amount);
    event TransferOut(uint256 amount);
    event SetBotAddress(address indexed _address);
}
