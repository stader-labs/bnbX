// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

interface IStakeHub {
    /**
     * @param operatorAddress the operator address of the validator to be delegated to
     * @param delegateVotePower whether to delegate vote power to the validator
     */
    function delegate(address operatorAddress, bool delegateVotePower) external payable;

    /**
     * @dev Undelegate BNB from a validator, fund is only claimable few days later
     * @param operatorAddress the operator address of the validator to be undelegated from
     * @param shares the shares to be undelegated
     */
    function undelegate(address operatorAddress, uint256 shares) external;

    /**
     * @param srcValidator the operator address of the validator to be redelegated from
     * @param dstValidator the operator address of the validator to be redelegated to
     * @param shares the shares to be redelegated
     * @param delegateVotePower whether to delegate vote power to the dstValidator
     */
    function redelegate(address srcValidator, address dstValidator, uint256 shares, bool delegateVotePower) external;

    /**
     * @notice get the credit contract address of a validator
     *
     * @param operatorAddress the operator address of the validator
     *
     * @return creditContract the credit contract address of the validator
     */
    function getValidatorCreditContract(address operatorAddress) external view returns (address creditContract);

    /**
     * @notice get the basic info of a validator
     *
     * @param operatorAddress the operator address of the validator
     *
     * @return createdTime the creation time of the validator
     * @return jailed whether the validator is jailed
     * @return jailUntil the jail time of the validator
     */
    function getValidatorBasicInfo(address operatorAddress)
        external
        view
        returns (uint256 createdTime, bool jailed, uint256 jailUntil);

    /**
     * @dev Claim the undelegated BNB from the pool after unbondPeriod
     * @param operatorAddress the operator address of the validator
     * @param requestNumber the request number of the undelegation. 0 means claim all
     */
    function claim(address operatorAddress, uint256 requestNumber) external;

    function unbondPeriod() external view returns (uint256);
    function minDelegationBNBChange() external view returns (uint256);

    function REDELEGATE_FEE_RATE_BASE() external view returns (uint256);
    function redelegateFeeRate() external view returns (uint256);
}
