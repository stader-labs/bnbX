// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./StakeManagerV2Setup.t.sol";
import { IStakeCredit } from "contracts/interfaces/IStakeCredit.sol";

contract StakeManagerV2Delegations is StakeManagerV2Setup {
    address preferredDepositOperator;

    function setUp() public override {
        super.setUp();
        preferredDepositOperator = operatorRegistry.preferredDepositOperator();
    }

    function testFuzz_revertWhenUserAmountLessThanMinDelegation(uint256 amountInBnb) public {
        uint256 minDelegateAmount = STAKE_HUB.minDelegationBNBChange();
        vm.assume(amountInBnb < minDelegateAmount);

        vm.expectRevert();
        hoax(user1, amountInBnb);
        stakeManagerV2.delegate{ value: amountInBnb }("referral");
    }

    function testFuzz_userDeposit(uint256 amountInBnb) public {
        uint256 minDelegateAmount = STAKE_HUB.minDelegationBNBChange();
        vm.assume(amountInBnb >= minDelegateAmount);
        vm.assume(amountInBnb < 1e35);

        address creditContract = STAKE_HUB.getValidatorCreditContract(preferredDepositOperator);
        uint256 validatorBalanceBefore = IStakeCredit(creditContract).getPooledBNB(address(stakeManagerV2));
        uint256 expectedBnbxAmount = stakeManagerV2.convertBnbToBnbX(amountInBnb);

        hoax(user1, amountInBnb);
        uint256 bnbxMinted = stakeManagerV2.delegate{ value: amountInBnb }("referral");

        assertEq(BnbX(bnbxAddr).balanceOf(user1), expectedBnbxAmount);
        assertEq(bnbxMinted, expectedBnbxAmount);

        uint256 validatorBalanceAfter = IStakeCredit(creditContract).getPooledBNB(address(stakeManagerV2));
        assertApproxEqAbs(validatorBalanceAfter, validatorBalanceBefore + amountInBnb, 2);
    }
}
