// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./StakeManagerV2Setup.t.sol";
import "contracts/interfaces/IStakeCredit.sol";

contract OperatorRegistryTests is StakeManagerV2Setup {
    uint256 minDelegateAmount;

    function setUp() public override {
        super.setUp();
        minDelegateAmount = STAKE_HUB.minDelegationBNBChange();
    }

    function test_revertsWhenReAddSameOperator() public {
        address oldOperator = operatorRegistry.preferredDepositOperator();

        vm.expectRevert(IOperatorRegistry.OperatorExisted.selector);
        vm.prank(manager);
        operatorRegistry.addOperator(oldOperator);
    }

    function test_addRandomAddressAsOperator() public {
        address newOperator = makeAddr("invalid-operator");

        vm.expectRevert(IOperatorRegistry.OperatorNotExisted.selector);
        vm.prank(manager);
        operatorRegistry.addOperator(newOperator);
    }

    function test_setInvalidOperatorAsPreferred() public {
        // below operator is not yet added
        address operator2 = 0xd34403249B2d82AAdDB14e778422c966265e5Fb5;
        assertFalse(operatorRegistry.operatorExists(operator2));

        vm.expectRevert(IOperatorRegistry.OperatorNotExisted.selector);
        vm.prank(manager);
        operatorRegistry.setPreferredDepositOperator(operator2);

        vm.expectRevert(IOperatorRegistry.OperatorNotExisted.selector);
        vm.prank(manager);
        operatorRegistry.setPreferredWithdrawalOperator(operator2);
    }

    function test_addOperator() public {
        uint256 numOperatorsBefore = operatorRegistry.getOperatorsLength();

        address operator2 = 0xd34403249B2d82AAdDB14e778422c966265e5Fb5;
        vm.prank(manager);
        operatorRegistry.addOperator(operator2);

        assertTrue(operatorRegistry.operatorExists(operator2));
        assertEq(operatorRegistry.getOperatorsLength(), numOperatorsBefore + 1);

        address[] memory operatorList = operatorRegistry.getOperators();
        assertEq(operatorList.length, numOperatorsBefore + 1);
    }

    function test_removePreferredOperator() public {
        address preferredDepositOperator = operatorRegistry.preferredDepositOperator();

        vm.expectRevert(IOperatorRegistry.OperatorIsPreferredDeposit.selector);
        vm.prank(manager);
        operatorRegistry.removeOperator(preferredDepositOperator);

        address operator2 = 0xd34403249B2d82AAdDB14e778422c966265e5Fb5;
        vm.prank(manager);
        operatorRegistry.addOperator(operator2);

        // set operator2 as preferred withdraw operator
        vm.prank(staderOperator);
        operatorRegistry.setPreferredWithdrawalOperator(operator2);

        vm.expectRevert(IOperatorRegistry.OperatorIsPreferredWithdrawal.selector);
        vm.prank(manager);
        operatorRegistry.removeOperator(operator2);
    }

    function test_removeOperatorWhenSomeDustRemains() public {
        address oldWithdrawOperator = operatorRegistry.preferredWithdrawalOperator();

        // new validator
        address newOperator = 0xd34403249B2d82AAdDB14e778422c966265e5Fb5;
        assertFalse(operatorRegistry.operatorExists(newOperator));

        // add a new validator
        vm.prank(manager);
        operatorRegistry.addOperator(newOperator);

        vm.startPrank(staderOperator);
        operatorRegistry.setPreferredDepositOperator(newOperator);
        operatorRegistry.setPreferredWithdrawalOperator(newOperator);
        vm.stopPrank();

        uint256 amount = 2 ether;
        hoax(user1, amount);
        uint256 bnbxMinted = stakeManagerV2.delegate{ value: amount }("referral");

        // set other operator as preferred
        vm.startPrank(staderOperator);
        operatorRegistry.setPreferredDepositOperator(oldWithdrawOperator);
        operatorRegistry.setPreferredWithdrawalOperator(oldWithdrawOperator);
        vm.stopPrank();

        uint256 bnbStakedAtOperator =
            IStakeCredit(STAKE_HUB.getValidatorCreditContract(newOperator)).getPooledBNB(address(stakeManagerV2));
        console2.log("bnbStakedAtOperator:", bnbStakedAtOperator);

        vm.expectRevert(IOperatorRegistry.DelegationExists.selector);
        vm.prank(manager);
        operatorRegistry.removeOperator(newOperator);

        // user requests withdraw
        vm.startPrank(user1);
        BnbX(bnbxAddr).approve(address(stakeManagerV2), bnbxMinted);
        uint256 negligibleAmount = operatorRegistry.negligibleAmount();
        stakeManagerV2.requestWithdraw(bnbxMinted - negligibleAmount / 2, "");
        vm.stopPrank();

        // unstake from operator
        vm.prank(staderOperator);
        stakeManagerV2.startBatchUndelegation(2, newOperator);

        // check and remove operator now
        bnbStakedAtOperator =
            IStakeCredit(STAKE_HUB.getValidatorCreditContract(newOperator)).getPooledBNB(address(stakeManagerV2));
        console2.log("bnbStakedAtOperator:", bnbStakedAtOperator);

        uint256 tvlBefore = stakeManagerV2.getActualStakeAcrossAllOperators();

        vm.prank(manager);
        operatorRegistry.removeOperator(newOperator);

        uint256 tvlAfter = stakeManagerV2.getActualStakeAcrossAllOperators();
        assertApproxEqAbs(tvlBefore, tvlAfter, negligibleAmount + 100);
    }

    function test_removeOperatorWhenSomeDustRemainsAfterRedelegation() public {
        address oldOperator = operatorRegistry.preferredDepositOperator();

        // new validator
        address newOperator = 0xd34403249B2d82AAdDB14e778422c966265e5Fb5;

        // add a new validator
        vm.prank(manager);
        operatorRegistry.addOperator(newOperator);

        vm.startPrank(staderOperator);
        operatorRegistry.setPreferredDepositOperator(newOperator);
        operatorRegistry.setPreferredWithdrawalOperator(newOperator);
        vm.stopPrank();

        uint256 amount = 2 ether;
        hoax(user1, amount);
        stakeManagerV2.delegate{ value: amount }("referral");

        // set other operator as preferred
        vm.startPrank(staderOperator);
        operatorRegistry.setPreferredDepositOperator(oldOperator);
        operatorRegistry.setPreferredWithdrawalOperator(oldOperator);
        vm.stopPrank();

        uint256 bnbStakedAtOperator =
            IStakeCredit(STAKE_HUB.getValidatorCreditContract(newOperator)).getPooledBNB(address(stakeManagerV2));
        console2.log("bnbStakedAtOperator:", bnbStakedAtOperator);

        vm.expectRevert(IOperatorRegistry.DelegationExists.selector);
        vm.prank(manager);
        operatorRegistry.removeOperator(newOperator);

        uint256 negligibleAmount = operatorRegistry.negligibleAmount();

        vm.prank(manager);
        stakeManagerV2.redelegate(newOperator, oldOperator, bnbStakedAtOperator - negligibleAmount + 1);

        // check and remove operator now
        bnbStakedAtOperator =
            IStakeCredit(STAKE_HUB.getValidatorCreditContract(newOperator)).getPooledBNB(address(stakeManagerV2));
        console2.log("bnbStakedAtOperator:", bnbStakedAtOperator);

        uint256 tvlBefore = stakeManagerV2.getActualStakeAcrossAllOperators();

        vm.prank(manager);
        operatorRegistry.removeOperator(newOperator);

        uint256 tvlAfter = stakeManagerV2.getActualStakeAcrossAllOperators();
        assertApproxEqAbs(tvlBefore, tvlAfter, negligibleAmount + 100);
    }

    function test_setNegligibleAmount() public {
        vm.expectRevert(IOperatorRegistry.NegligibleAmountTooHigh.selector);
        vm.startPrank(manager);
        operatorRegistry.setNegligibleAmount(1e15 + 1);

        operatorRegistry.setNegligibleAmount(1e8);
        assertEq(operatorRegistry.negligibleAmount(), 1e8);
        vm.stopPrank();
    }

    function test_pause_unpause() public {
        vm.prank(manager);
        operatorRegistry.pause();
        assertTrue(operatorRegistry.paused());

        vm.expectRevert();
        vm.prank(staderOperator);
        operatorRegistry.unpause();

        vm.prank(admin);
        operatorRegistry.unpause();
        assertFalse(operatorRegistry.paused());
    }
}
