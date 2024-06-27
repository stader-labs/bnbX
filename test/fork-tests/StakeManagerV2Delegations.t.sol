// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./StakeManagerV2Setup.t.sol";

contract StakeManagerV2Delegations is StakeManagerV2Setup {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_revertWhenUserAmountLessThanMinDelegation(uint256 amountInBnb) public {
        uint256 minDelegateAmount = STAKE_HUB.minDelegationBNBChange();
        vm.assume(amountInBnb < minDelegateAmount);

        vm.deal(user1, amountInBnb);
        vm.expectRevert();
        vm.prank(user1);
        stakeManagerV2.delegate{ value: amountInBnb }("referral");
    }

    function testFuzz_userDeposit(uint256 amountInBnb) public {
        uint256 minDelegateAmount = STAKE_HUB.minDelegationBNBChange();
        vm.assume(amountInBnb >= minDelegateAmount);
        vm.assume(amountInBnb < 1e35);

        uint256 expectedBnbxAmount = stakeManagerV2.convertBnbToBnbX(amountInBnb);

        vm.deal(user1, amountInBnb);

        vm.prank(user1);
        uint256 bnbxMinted = stakeManagerV2.delegate{ value: amountInBnb }("referral");

        assertEq(BnbX(bnbxAddr).balanceOf(user1), expectedBnbxAmount);
        assertEq(bnbxMinted, expectedBnbxAmount);
    }
}
