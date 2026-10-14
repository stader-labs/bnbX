// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "contracts/StakeManagerV2.sol";
import "contracts/ProtocolConstants.sol";

/// @dev Fork tests for the raised fee cap (`MAX_ALLOWED_FEE_BPS` = 100%).
///
/// Standalone setup, same shape as `StakeManagerV2Custody`: upgrade the live
/// proxy to the impl built from this source, then exercise `setFeeBps`.
contract StakeManagerV2FeeCap is Test {
    address internal proxyAdmin = 0xF90e293D34a42CB592Be6BE6CA19A9963655673C;
    address internal timelock = 0xD990A252E7e36700d47520e46cD2B3E446836488;
    address internal admin = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig (DEFAULT_ADMIN_ROLE)

    StakeManagerV2 internal stakeManagerV2 = StakeManagerV2(payable(0x3b961e83400D51e6E1AF5c450d3C7d7b80588d28));

    event SetFeeBps(uint256 _feeBps);

    function setUp() public {
        string memory rpcUrl = vm.envString("BSC_MAINNET_RPC_URL");
        vm.createSelectFork(rpcUrl);

        address newImpl = address(new StakeManagerV2());
        vm.prank(timelock);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(stakeManagerV2)), newImpl);

        // `setFeeBps` calls `updateER`, which is `whenNotPaused`.
        if (stakeManagerV2.paused()) {
            vm.prank(admin);
            stakeManagerV2.unpause();
        }
    }

    function test_constant_is100Percent() public pure {
        assertEq(ProtocolConstants.MAX_ALLOWED_FEE_BPS, 10_000);
        assertEq(ProtocolConstants.MAX_ALLOWED_FEE_BPS, ProtocolConstants.BPS_DENOM);
    }

    function test_setFeeBps_allows100Percent() public {
        vm.expectEmit(false, false, false, true);
        emit SetFeeBps(10_000);

        vm.prank(admin);
        stakeManagerV2.setFeeBps(10_000);
        assertEq(stakeManagerV2.feeBps(), 10_000);
    }

    function test_setFeeBps_allowsFormerCapAndAbove() public {
        vm.startPrank(admin);
        stakeManagerV2.setFeeBps(5000);
        assertEq(stakeManagerV2.feeBps(), 5000);
        stakeManagerV2.setFeeBps(5001);
        assertEq(stakeManagerV2.feeBps(), 5001);
        vm.stopPrank();
    }

    function test_setFeeBps_revertsAbove100Percent() public {
        vm.expectRevert(IStakeManagerV2.MaxLimitReached.selector);
        vm.prank(admin);
        stakeManagerV2.setFeeBps(10_001);
    }

    function test_setFeeBps_revertsForNonAdmin() public {
        vm.expectRevert();
        vm.prank(makeAddr("attacker"));
        stakeManagerV2.setFeeBps(10_000);
    }

    function test_updateER_at100Percent_doesNotRevert() public {
        vm.prank(admin);
        stakeManagerV2.setFeeBps(10_000);

        uint256 totalDelegatedBefore = stakeManagerV2.totalDelegated();
        stakeManagerV2.updateER();
        // After an update the pooled amount is fully accounted for; with a
        // 100% fee any growth is minted to the treasury rather than accruing
        // to the exchange rate.
        assertGe(stakeManagerV2.totalDelegated(), totalDelegatedBefore);
    }
}
