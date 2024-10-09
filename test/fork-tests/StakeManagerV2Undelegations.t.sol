// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./StakeManagerV2Setup.t.sol";

contract StakeManagerV2Undelegations is StakeManagerV2Setup {
    uint256 amountDeposited = 1e10 ether;

    function setUp() public override {
        super.setUp();

        // set deposit and withdrawal operator same
        address withdrawalOperator = operatorRegistry.preferredWithdrawalOperator();
        vm.prank(staderOperator);
        operatorRegistry.setPreferredDepositOperator(withdrawalOperator);

        startHoax(user1);
        stakeManagerV2.delegate{ value: amountDeposited }("referral");
        BnbX(bnbxAddr).approve(address(stakeManagerV2), 2 * amountDeposited);
        vm.stopPrank();

        startHoax(user2);
        stakeManagerV2.delegate{ value: amountDeposited }("referral");
        BnbX(bnbxAddr).approve(address(stakeManagerV2), 2 * amountDeposited);
        vm.stopPrank();
    }

    function test_getBnbxToBurnForBatchSize() public {
        _batchUndelegateSetup(3 ether, 5 ether);

        assertEq(stakeManagerV2.getBnbxToBurnForBatchSize(3), 11 ether);
        assertEq(stakeManagerV2.getBnbxToBurnForBatchSize(1), 3 ether);
        assertEq(stakeManagerV2.getBnbxToBurnForBatchSize(2), 8 ether);
        assertEq(stakeManagerV2.getBnbxToBurnForBatchSize(6), 24 ether);
        assertEq(stakeManagerV2.getBnbxToBurnForBatchSize(7), 24 ether);
        assertEq(stakeManagerV2.getBnbxToBurnForBatchSize(0), 0);
    }

    function test_revertWhenWithdrawAmountIsLow(uint256 bnbxAmount) public {
        vm.assume(bnbxAmount < stakeManagerV2.minWithdrawableBnbx());

        vm.expectRevert(IStakeManagerV2.WithdrawalBelowMinimum.selector);
        vm.prank(user1);
        stakeManagerV2.requestWithdraw(bnbxAmount, "");
    }

    function testFuzz_userWithdrawAndBatchCreation(uint256 bnbxToWithdraw) public {
        uint256 userBnbxBalance = BnbX(bnbxAddr).balanceOf(user1);
        vm.assume(bnbxToWithdraw >= stakeManagerV2.minWithdrawableBnbx());
        vm.assume(bnbxToWithdraw <= userBnbxBalance);

        assertEq(stakeManagerV2.getUserRequestIds(user1).length, 0);

        vm.prank(user1);
        stakeManagerV2.requestWithdraw(bnbxToWithdraw, "");

        assertEq(stakeManagerV2.getUnprocessedWithdrawalRequestCount(), 1);

        uint256[] memory userReqIds = stakeManagerV2.getUserRequestIds(user1);
        assertEq(userReqIds.length, 1);

        WithdrawalRequest memory request = stakeManagerV2.getUserRequestInfo(userReqIds[0]);
        assertEq(request.user, user1);
        assertEq(request.processed, false);
        assertEq(request.claimed, false);
        assertEq(request.amountInBnbX, bnbxToWithdraw);
        assertEq(request.batchId, type(uint256).max);

        uint256 batchId = stakeManagerV2.getBatchWithdrawalRequestCount();
        vm.prank(staderOperator);
        stakeManagerV2.startBatchUndelegation(10, address(0));
        assertEq(stakeManagerV2.getBatchWithdrawalRequestCount(), batchId + 1);

        BatchWithdrawalRequest memory batchRequest = stakeManagerV2.getBatchWithdrawalRequestInfo(batchId);
        assertApproxEqAbs(batchRequest.amountInBnb, stakeManagerV2.convertBnbXToBnb(bnbxToWithdraw), 5);
        assertEq(batchRequest.amountInBnbX, bnbxToWithdraw);
        assertEq(batchRequest.unlockTime, block.timestamp + STAKE_HUB.unbondPeriod());
        assertEq(batchRequest.operator, operatorRegistry.preferredWithdrawalOperator());
        assertEq(batchRequest.isClaimable, false);

        request = stakeManagerV2.getUserRequestInfo(userReqIds[0]);
        assertEq(request.user, user1);
        assertEq(request.processed, true);
        assertEq(request.claimed, false);
        assertEq(request.amountInBnbX, bnbxToWithdraw);
        assertEq(request.batchId, batchId);
    }

    function test_claimWithdrawal() public {
        vm.startPrank(user1);
        uint256 amountMinted = stakeManagerV2.delegate{ value: 1 ether }("referral");
        amountMinted = 1e16;
        uint256 amountOfBnbExpected = stakeManagerV2.convertBnbXToBnb(amountMinted);
        /* --------------------------- withdrawal request --------------------------- */
        // there has to be a withdrawalrequest
        vm.startPrank(user1);
        BnbX(bnbxAddr).approve(address(stakeManagerV2), type(uint256).max);
        stakeManagerV2.requestWithdraw(amountMinted, "");
        assertEq(stakeManagerV2.getUnprocessedWithdrawalRequestCount(), 1);
        assertEq(BnbX(bnbxAddr).balanceOf(address(stakeManagerV2)), amountMinted);
        vm.stopPrank();
        /* ---------------------------- startBatch undelegation first ------------------------
        ---- */
        vm.startPrank(staderOperator);
        stakeManagerV2.startBatchUndelegation(1, address(0));
        uint256 batchWithdrawalRequestCount = stakeManagerV2.getBatchWithdrawalRequestCount();
        console.log("batchWithdrawalRequestCount: ", batchWithdrawalRequestCount);
        vm.stopPrank();
        /* ------------------- have to complete batch undelegation ------------------ */
        // this is to change the state of the batch request and make it claimable
        vm.startPrank(staderOperator);
        skip(7 days);
        uint256 firstUnbondingBatchIndexBefore = stakeManagerV2.firstUnbondingBatchIndex();

        stakeManagerV2.completeBatchUndelegation();
        uint256 firstUnbondingBatchIndexAfter = stakeManagerV2.firstUnbondingBatchIndex();
        assertEq(firstUnbondingBatchIndexAfter, firstUnbondingBatchIndexBefore + 1);
        vm.stopPrank();

        uint256 userBalanceBefore = user1.balance;
        vm.startPrank(user1);
        stakeManagerV2.claimWithdrawal(0);
        vm.stopPrank();

        uint256 userBalanceAfter = user1.balance;
        assertApproxEqAbs(userBalanceAfter, userBalanceBefore + amountOfBnbExpected, 2);
    }

    function test_E2E_MultipleUserWithdrawal() public {
        _batchUndelegateSetup(5 ether, 3 ether);

        assertEq(stakeManagerV2.getUserRequestIds(user1).length, 3);
        assertEq(stakeManagerV2.getUserRequestIds(user2).length, 3);
        assertEq(stakeManagerV2.getUnprocessedWithdrawalRequestCount(), 6);

        uint256 prevNumBatches = stakeManagerV2.getBatchWithdrawalRequestCount();

        vm.startPrank(staderOperator);
        stakeManagerV2.startBatchUndelegation(2, address(0));
        assertEq(stakeManagerV2.getUnprocessedWithdrawalRequestCount(), 4);

        stakeManagerV2.startBatchUndelegation(6, address(0));
        assertEq(stakeManagerV2.getUnprocessedWithdrawalRequestCount(), 0);

        vm.stopPrank();

        assertEq(stakeManagerV2.getBatchWithdrawalRequestCount(), prevNumBatches + 2);

        vm.warp(block.timestamp + STAKE_HUB.unbondPeriod() + 1);

        vm.prank(staderOperator);
        stakeManagerV2.completeBatchUndelegation();

        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        vm.prank(user2);
        stakeManagerV2.claimWithdrawal(0);
    }

    function testFuzz_userClaimRestrictedBeforeCompleteBatchUndelegation(uint256 amount1, uint256 amount2) public {
        uint256 minWithdrawableBnbx = stakeManagerV2.minWithdrawableBnbx();
        uint256 userBnbxBalance = BnbX(bnbxAddr).balanceOf(user1);
        vm.assume(amount1 >= minWithdrawableBnbx && amount1 < userBnbxBalance / 2);
        vm.assume(amount2 >= minWithdrawableBnbx && amount2 < userBnbxBalance / 2);

        // user unstakes
        vm.prank(user1);
        stakeManagerV2.requestWithdraw(amount1, "");

        // user tries to claim before startBatchUndelegation
        vm.expectRevert(IStakeManagerV2.NotProcessed.selector);
        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        // staderOperator starts batch undelegation
        vm.prank(staderOperator);
        stakeManagerV2.startBatchUndelegation(1, address(0));

        // user tries to claim before completeBatchUndelegation
        vm.expectRevert(IStakeManagerV2.Unbonding.selector);
        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        skip(7 days);

        // user tries to claim again after 7 days before completeBatchUndelegation
        vm.expectRevert(IStakeManagerV2.Unbonding.selector);
        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        // someone (staderOperator) completes batch undelegation
        stakeManagerV2.completeBatchUndelegation();

        // user successfully claims after completeBatchUndelegation
        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        // user tries to claim again
        vm.expectRevert(IStakeManagerV2.NoWithdrawalRequests.selector);
        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        // ---------------------------------------------------------------- //
        // user requests withdrawal again
        vm.prank(user1);
        stakeManagerV2.requestWithdraw(amount2, "");

        // user tries to claim before startBatchUndelegation
        vm.expectRevert(IStakeManagerV2.NotProcessed.selector);
        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        // staderOperator starts batch undelegation
        vm.prank(staderOperator);
        stakeManagerV2.startBatchUndelegation(1, address(0));

        // user tries to claim before completeBatchUndelegation
        vm.expectRevert(IStakeManagerV2.Unbonding.selector);
        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        skip(7 days);

        // user tries to claim again after 7 days before completeBatchUndelegation
        vm.expectRevert(IStakeManagerV2.Unbonding.selector);
        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        // someone (staderOperator) completes batch undelegation
        stakeManagerV2.completeBatchUndelegation();

        // user successfully claims after completeBatchUndelegation
        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);

        // user tries to claim again
        vm.expectRevert(IStakeManagerV2.NoWithdrawalRequests.selector);
        vm.prank(user1);
        stakeManagerV2.claimWithdrawal(0);
    }

    function test_startBatchUndelegationSucceedsForFewWithdrawRequests() public {
        _batchUndelegateSetup(5 ether, 3 ether);

        assertEq(stakeManagerV2.getUnprocessedWithdrawalRequestCount(), 6);
        uint256 prevNumBatches = stakeManagerV2.getBatchWithdrawalRequestCount();

        vm.prank(staderOperator);
        stakeManagerV2.startBatchUndelegation(8, address(0));

        assertEq(stakeManagerV2.getBatchWithdrawalRequestCount(), prevNumBatches + 1);
    }

    function _batchUndelegateSetup(uint256 bnbxAmount1, uint256 bnbxAmount2) internal {
        vm.prank(user1);
        stakeManagerV2.requestWithdraw(bnbxAmount1, "");
        vm.prank(user2);
        stakeManagerV2.requestWithdraw(bnbxAmount2, "");

        vm.prank(user1);
        stakeManagerV2.requestWithdraw(bnbxAmount1, "");
        vm.prank(user2);
        stakeManagerV2.requestWithdraw(bnbxAmount2, "");

        vm.prank(user1);
        stakeManagerV2.requestWithdraw(bnbxAmount1, "");
        vm.prank(user2);
        stakeManagerV2.requestWithdraw(bnbxAmount2, "");
    }
}
