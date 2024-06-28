// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./StakeManagerV2Setup.t.sol";

contract StakeManagerV2Undelegations is StakeManagerV2Setup {
    uint256 amountDeposited = 1e10 ether;

    function setUp() public override {
        super.setUp();

        startHoax(user1);
        stakeManagerV2.delegate{ value: amountDeposited }("referral");
        BnbX(bnbxAddr).approve(address(stakeManagerV2), 2 * amountDeposited);
        vm.stopPrank();

        startHoax(user2);
        stakeManagerV2.delegate{ value: amountDeposited }("referral");
        BnbX(bnbxAddr).approve(address(stakeManagerV2), 2 * amountDeposited);
        vm.stopPrank();
    }

    function test_revertWhenWithdrawAmountIsZero() public {
        vm.expectRevert();
        vm.prank(user1);
        stakeManagerV2.requestWithdraw(0);
    }

    function testFuzz_userWithdraw(uint256 bnbxToWithdraw) public {
        uint256 userBnbxBalance = BnbX(bnbxAddr).balanceOf(user1);
        vm.assume(bnbxToWithdraw > 0);
        vm.assume(bnbxToWithdraw <= userBnbxBalance);

        assertEq(stakeManagerV2.getUserRequestIds(user1).length, 0);

        vm.prank(user1);
        stakeManagerV2.requestWithdraw(bnbxToWithdraw);

        assertEq(stakeManagerV2.getUserRequestIds(user1).length, 1);
    }

    function test_e2eUserWithdrawal() public {
        _batchUndelegateSetup(5 ether, 3 ether);

        assertEq(stakeManagerV2.getUserRequestIds(user1).length, 3);
        assertEq(stakeManagerV2.getUserRequestIds(user2).length, 3);

        vm.prank(staderOperator);
        stakeManagerV2.startBatchUndelegation(2, address(0));

        assertEq(stakeManagerV2.getBatchWithdrawalRequestCount(), 1);

        vm.warp(block.timestamp + STAKE_HUB.unbondPeriod() + 1);

        vm.prank(staderOperator);
        stakeManagerV2.completeBatchUndelegation();

        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        vm.prank(user2);
        stakeManagerV2.claimWithdrawal(0);
    }

    function _batchUndelegateSetup(uint256 bnbxAmount1, uint256 bnbxAmount2) internal {
        vm.prank(user1);
        stakeManagerV2.requestWithdraw(bnbxAmount1);
        vm.prank(user2);
        stakeManagerV2.requestWithdraw(bnbxAmount2);

        vm.prank(user1);
        stakeManagerV2.requestWithdraw(bnbxAmount1);
        vm.prank(user2);
        stakeManagerV2.requestWithdraw(bnbxAmount2);

        vm.prank(user1);
        stakeManagerV2.requestWithdraw(bnbxAmount1);
        vm.prank(user2);
        stakeManagerV2.requestWithdraw(bnbxAmount2);
    }
}
