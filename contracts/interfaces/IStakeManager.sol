//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title Stake Manager Contract
 * @dev Handles Staking of Bnb on BSC
 */
interface IStakeManager {
    struct DelegateRequest {
        uint256 startTime;
        uint256 endTime;
        uint256 amount;
    }

    /**
     * @param _bnbX - Address of BnbX Token on Binance Smart Chain
     * @param _manager - Address of the manager
     * @param _tokenHub - Address of the manager
     * @param _bcDepositWallet - Address of deposit Bot Wallet on Beacon Chain
     */
    function initialize(
        address _bnbX,
        address _manager,
        address _tokenHub,
        address _bcDepositWallet
    ) external;

    /**
     * @dev Allows user to deposit Bnb at BSC and mints BnbX for the user
     */
    function deposit() external payable;

    function startDelegation() external payable returns (uint256);

    function completeDelegation(uint256 uuid) external;

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////            ***Helpers & Utilities***               ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @dev Calculates amount of BnbX for `_amount` Bnb
    function convertBnbToBnbX(uint256 _amount) external view returns (uint256);

    function getContracts()
        external
        view
        returns (
            address _bnbX,
            address _tokenHub,
            address _bcDepositWallet
        );

    function getTokenHubRelayFee() external view returns (uint256);

    event Delegate(uint256 uuid, uint256 amount);
    event TransferOut(uint256 amount);
}
