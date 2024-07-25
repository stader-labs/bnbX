// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./StakeManagerV2Setup.t.sol";
import { IStakeCredit } from "contracts/interfaces/IStakeCredit.sol";

contract StakeManagerV2Delegations is StakeManagerV2Setup {
    address preferredDepositOperator;
    uint256 minDelegateAmount;

    function setUp() public override {
        super.setUp();
        minDelegateAmount = STAKE_HUB.minDelegationBNBChange();
        preferredDepositOperator = operatorRegistry.preferredDepositOperator();
    }

    function testFuzz_revertWhenUserAmountLessThanMinDelegation(uint256 amountInBnb) public {
        vm.assume(amountInBnb < minDelegateAmount);

        vm.expectRevert();
        hoax(user1, amountInBnb);
        stakeManagerV2.delegate{ value: amountInBnb }("referral");
    }

    function testFuzz_userDeposit(uint256 amountInBnb) public {
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

    function testFuzz_redelegation(uint256 amount, uint256 redelegationAmount) public {
        vm.assume(amount < 1e35);
        vm.assume(amount >= minDelegateAmount);
        vm.assume(redelegationAmount >= minDelegateAmount);
        vm.assume(redelegationAmount <= amount);

        // new validator
        address toOperator = 0xd34403249B2d82AAdDB14e778422c966265e5Fb5;

        // add a new validator
        vm.prank(manager);
        operatorRegistry.addOperator(toOperator);

        hoax(user1, amount);
        stakeManagerV2.delegate{ value: amount }("referral");

        uint256 totalStakedBnb = stakeManagerV2.getActualStakeAcrossAllOperators();
        vm.prank(manager);
        stakeManagerV2.redelegate(preferredDepositOperator, toOperator, redelegationAmount);

        uint256 totalStakedBnbAfter = stakeManagerV2.getActualStakeAcrossAllOperators();
        assertApproxEqAbs(
            totalStakedBnbAfter, totalStakedBnb - stakeManagerV2.getRedelegationFee(redelegationAmount), 100
        );
    }
}
