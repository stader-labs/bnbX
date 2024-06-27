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
}
