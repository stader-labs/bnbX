// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./StakeManagerV2Setup.t.sol";

contract StakeManagerV2BasicChecks is StakeManagerV2Setup {
    function setUp() public override {
        super.setUp();
    }

    function test_basicChecks() public view {
        assertNotEq(stakeManagerV2.staderTreasury(), address(0));
        assertNotEq(stakeManagerV2.maxExchangeRateSlippageBps(), 0);
        assertEq(address(stakeManagerV2.BNBX()), bnbxAddr);
        assertGt(stakeManagerV2.convertBnbXToBnb(1 ether), 1 ether);
        assertGt(stakeManagerV2.maxActiveRequestsPerUser(), 0);
    }

    function test_updateER() public {
        uint256 totalDelegated1 = stakeManagerV2.totalDelegated();
        uint256 treasuryBNBxBal1 = _bnbxBalance(treasury);
        stakeManagerV2.updateER();
        uint256 totalDelegated2 = stakeManagerV2.totalDelegated();
        uint256 treasuryBNBxBal2 = _bnbxBalance(treasury);

        if (totalDelegated2 <= totalDelegated1) {
            assertApproxEqAbs(totalDelegated1, totalDelegated2, 5);
            assertEq(treasuryBNBxBal1, treasuryBNBxBal2);
        } else {
            assertGt(treasuryBNBxBal2, treasuryBNBxBal1);
        }
    }

    function test_setStaderTreasury() public {
        vm.startPrank(admin);
        address newTreasury = makeAddr("new-treasury");
        stakeManagerV2.setStaderTreasury(newTreasury);
    }

    function test_setFeeBps() public {
        vm.startPrank(admin);
        uint256 newFeeBps = 100;
        stakeManagerV2.setFeeBps(newFeeBps);
        assertEq(stakeManagerV2.feeBps(), newFeeBps);

        vm.expectRevert(IStakeManagerV2.MaxLimitReached.selector);
        stakeManagerV2.setFeeBps(5001);
    }

    function test_setMaxActiveRequestsPerUser() public {
        vm.startPrank(admin);
        uint256 newMaxActiveRequestsPerUser = 100;
        stakeManagerV2.setMaxActiveRequestsPerUser(newMaxActiveRequestsPerUser);
        assertEq(stakeManagerV2.maxActiveRequestsPerUser(), newMaxActiveRequestsPerUser);
    }

    function test_setMaxExchangeRateSlippageBps() public {
        vm.startPrank(admin);
        uint256 newMaxExchangeRateSlippageBps = 100;
        stakeManagerV2.setMaxExchangeRateSlippageBps(newMaxExchangeRateSlippageBps);
        assertEq(stakeManagerV2.maxExchangeRateSlippageBps(), newMaxExchangeRateSlippageBps);
    }
}
