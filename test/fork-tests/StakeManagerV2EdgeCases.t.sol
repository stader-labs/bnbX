// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./StakeManagerV2Setup.t.sol";
import "contracts/interfaces/IStakeCredit.sol";

contract StakeManagerV2EdgeCases is StakeManagerV2Setup {
    uint256 minDelegateAmount;

    function setUp() public override {
        super.setUp();
        minDelegateAmount = STAKE_HUB.minDelegationBNBChange();
    }

    function test_redelegationAndUnstakeFromSameOperator(uint256 amount) public {
        vm.assume(amount < 1e35);
        vm.assume(amount >= minDelegateAmount + 100);

        address oldOperator = operatorRegistry.preferredDepositOperator();

        // new validator
        address toOperator = 0xd34403249B2d82AAdDB14e778422c966265e5Fb5;

        // add a new validator
        vm.prank(manager);
        operatorRegistry.addOperator(toOperator);

        vm.prank(staderOperator);
        operatorRegistry.setPreferredDepositOperator(toOperator);

        hoax(user1, amount);
        stakeManagerV2.delegate{ value: amount }("referral");

        // redelegate all amount
        vm.prank(manager);
        stakeManagerV2.redelegate(toOperator, oldOperator, amount);

        uint256 amountToWithdraw = amount / 2;

        // user requests withdraw
        vm.startPrank(user1);
        BnbX(bnbxAddr).approve(address(stakeManagerV2), amount);
        stakeManagerV2.requestWithdraw(amount / 2, "");
        vm.stopPrank();

        // lets try unstaking from the same toOperator (which does not have any funds delegated by us)
        vm.expectRevert(IStakeManagerV2.NoWithdrawalRequests.selector);
        vm.prank(staderOperator);
        stakeManagerV2.startBatchUndelegation(amountToWithdraw, toOperator);
    }

    function test_updateER_AfterExtraDelegation() public {
        // initial update ER
        stakeManagerV2.updateER();

        // increase the exchange rate by a little bit
        hoax(manager, 10 ether);
        stakeManagerV2.delegateWithoutMinting{ value: 10 ether }();

        uint256 totalDelegated2 = stakeManagerV2.totalDelegated();
        uint256 treasuryBNBxBal2 = _bnbxBalance(treasury);
        stakeManagerV2.updateER();
        uint256 totalDelegated3 = stakeManagerV2.totalDelegated();
        uint256 treasuryBNBxBal3 = _bnbxBalance(treasury);

        assertApproxEqAbs(totalDelegated3, totalDelegated2, 5);
        // no bnbx fees is minted in this case
        assertEq(treasuryBNBxBal3, treasuryBNBxBal2);
    }

    function test_updateER_whenRewardsEnters() public {
        uint256 totalDelegated2 = stakeManagerV2.totalDelegated();
        uint256 treasuryBNBxBal2 = _bnbxBalance(treasury);

        // add mock rewards
        address operator1 = operatorRegistry.preferredDepositOperator();
        address creditContract = STAKE_HUB.getValidatorCreditContract(operator1);
        uint256 pooledBNBAtOperator = IStakeCredit(creditContract).getPooledBNB(address(stakeManagerV2));
        vm.mockCall(
            creditContract,
            abi.encodeWithSelector(IStakeCredit.getPooledBNB.selector),
            abi.encode(pooledBNBAtOperator + 10 ether)
        );

        stakeManagerV2.updateER();
        uint256 totalDelegated3 = stakeManagerV2.totalDelegated();
        uint256 treasuryBNBxBal3 = _bnbxBalance(treasury);

        // total delegated increases and treasury is minted bnbx
        assertGt(totalDelegated3, totalDelegated2);
        assertGt(treasuryBNBxBal3, treasuryBNBxBal2);
    }

    function test_forceUpdateER_whenVeryHighRewards() public {
        uint256 totalDelegated2 = stakeManagerV2.totalDelegated();
        uint256 treasuryBNBxBal2 = _bnbxBalance(treasury);

        // add mock rewards
        address operator1 = operatorRegistry.preferredDepositOperator();
        address creditContract = STAKE_HUB.getValidatorCreditContract(operator1);
        uint256 pooledBNBAtOperator = IStakeCredit(creditContract).getPooledBNB(address(stakeManagerV2));
        vm.mockCall(
            creditContract,
            abi.encodeWithSelector(IStakeCredit.getPooledBNB.selector),
            abi.encode(pooledBNBAtOperator + 100_000 ether) // high rewards
        );

        vm.expectRevert(); // ExchangeRateOutOfBounds
        stakeManagerV2.updateER();

        vm.prank(admin);
        stakeManagerV2.forceUpdateER();
        uint256 totalDelegated3 = stakeManagerV2.totalDelegated();
        uint256 treasuryBNBxBal3 = _bnbxBalance(treasury);

        // total delegated increases and treasury is minted bnbx
        assertGt(totalDelegated3, totalDelegated2);
        assertGt(treasuryBNBxBal3, treasuryBNBxBal2);
    }
}
