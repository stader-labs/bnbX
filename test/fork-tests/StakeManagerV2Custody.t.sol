// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "contracts/StakeManagerV2.sol";

/// @dev Fork tests for the custody sweep mechanism added to `StakeManagerV2`.
///
/// Standalone setup (does NOT inherit `StakeManagerV2Setup`) — the parent
/// fixture exercises `STAKE_HUB` via `_clearCurrentPendingTransactions`
/// which requires an archive-depth BSC RPC. These tests only need the
/// proxy upgraded to the new impl + funded with BNB, so we bypass that
/// machinery and stay compatible with non-archive BSC endpoints.
contract StakeManagerV2Custody is Test {
    // Mainnet addresses (see StakeManagerV2Setup.t.sol).
    address internal proxyAdmin = 0xF90e293D34a42CB592Be6BE6CA19A9963655673C;
    address internal timelock = 0xD990A252E7e36700d47520e46cD2B3E446836488;
    address internal admin = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig (DEFAULT_ADMIN_ROLE)
    address internal manager = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig (MANAGER_ROLE)

    StakeManagerV2 internal stakeManagerV2 = StakeManagerV2(payable(0x3b961e83400D51e6E1AF5c450d3C7d7b80588d28));

    address internal custody;
    address internal attacker;

    event SetCustodyDelay(uint256 _sweepToCustodyTimestamp);
    event SweptToCustody(address indexed _asset, address indexed _custody, uint256 _amount);

    function setUp() public {
        string memory rpcUrl = vm.envString("BSC_MAINNET_RPC_URL");
        vm.createSelectFork(rpcUrl);

        custody = makeAddr("custody");
        attacker = makeAddr("attacker");

        address newImpl = address(new StakeManagerV2());
        vm.prank(timelock);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(stakeManagerV2)), newImpl);
    }

    // -------- access control --------

    function test_setCustodyDelay_revertsForNonAdmin() public {
        vm.expectRevert();
        vm.prank(attacker);
        stakeManagerV2.setCustodyDelay(1 days);
    }

    function test_sweepToCustody_revertsForNonAdmin() public {
        _arm(1 days);
        skip(1 days);
        _fundContract(1 ether);

        vm.expectRevert();
        vm.prank(attacker);
        stakeManagerV2.sweepToCustody(address(0), custody);
    }

    // -------- setCustodyDelay --------

    function test_setCustodyDelay_setsTargetAndEmits() public {
        uint256 delay = 7 days;
        uint256 expectedTarget = block.timestamp + delay;

        vm.expectEmit(false, false, false, true);
        emit SetCustodyDelay(expectedTarget);

        vm.prank(admin);
        stakeManagerV2.setCustodyDelay(delay);

        assertEq(stakeManagerV2.sweepToCustodyTimestamp(), expectedTarget);
    }

    function test_setCustodyDelay_revertsOnZero() public {
        vm.prank(admin);
        vm.expectRevert(IStakeManagerV2.ZeroCustodyDelay.selector);
        stakeManagerV2.setCustodyDelay(0);
    }

    function test_setCustodyDelay_overwritesTargetOnReconfig() public {
        _arm(7 days);
        uint256 firstTarget = stakeManagerV2.sweepToCustodyTimestamp();

        skip(1 days);

        _arm(3 days);
        uint256 secondTarget = stakeManagerV2.sweepToCustodyTimestamp();

        assertEq(secondTarget, block.timestamp + 3 days);
        assertTrue(secondTarget != firstTarget);
    }

    function test_setCustodyDelay_reconfigGatesSweep() public {
        _arm(7 days);
        skip(6 days);
        _fundContract(1 ether);

        _arm(7 days);

        vm.prank(admin);
        vm.expectRevert(IStakeManagerV2.CustodyDelayNotElapsed.selector);
        stakeManagerV2.sweepToCustody(address(0), custody);

        skip(7 days);
        vm.prank(admin);
        stakeManagerV2.sweepToCustody(address(0), custody);
        assertEq(custody.balance, 1 ether);
    }

    // -------- sweepToCustody negative paths --------

    function test_sweepToCustody_revertsBeforeArming() public {
        _fundContract(1 ether);

        vm.prank(admin);
        vm.expectRevert(IStakeManagerV2.CustodyDelayNotElapsed.selector);
        stakeManagerV2.sweepToCustody(address(0), custody);
    }

    function test_sweepToCustody_revertsBeforeTargetElapsed() public {
        _arm(7 days);
        _fundContract(1 ether);
        skip(6 days);

        vm.prank(admin);
        vm.expectRevert(IStakeManagerV2.CustodyDelayNotElapsed.selector);
        stakeManagerV2.sweepToCustody(address(0), custody);
    }

    function test_sweepToCustody_revertsOnZeroCustody() public {
        _arm(1 days);
        skip(1 days);
        _fundContract(1 ether);

        vm.prank(admin);
        vm.expectRevert(IStakeManagerV2.ZeroAddress.selector);
        stakeManagerV2.sweepToCustody(address(0), address(0));
    }

    function test_sweepToCustody_revertsOnZeroAmount() public {
        _arm(1 days);
        skip(1 days);
        // contract has 0 BNB — full-balance sweep reverts

        vm.prank(admin);
        vm.expectRevert(IStakeManagerV2.ZeroAmount.selector);
        stakeManagerV2.sweepToCustody(address(0), custody);
    }

    function test_sweepToCustody_revertsOnFailedTransfer() public {
        _arm(1 days);
        skip(1 days);
        _fundContract(1 ether);

        address rejector = address(new RejectETH());

        vm.prank(admin);
        vm.expectRevert(IStakeManagerV2.TransferFailed.selector);
        stakeManagerV2.sweepToCustody(address(0), rejector);
    }

    // -------- sweepToCustody happy path --------

    function test_sweepToCustody_sweepsFullBalanceAndEmits() public {
        _arm(1 days);
        skip(1 days);
        _fundContract(5 ether);

        uint256 preCustody = custody.balance;

        vm.expectEmit(true, true, false, true);
        emit SweptToCustody(address(0), custody, 5 ether);

        vm.prank(admin);
        stakeManagerV2.sweepToCustody(address(0), custody);

        assertEq(custody.balance, preCustody + 5 ether);
        assertEq(address(stakeManagerV2).balance, 0);
        assertTrue(stakeManagerV2.assetCustodied());
    }

    function test_sweepToCustody_setsAssetCustodiedAndBlocksRedeem() public {
        _arm(1 days);
        skip(1 days);
        _fundContract(1 ether);

        assertFalse(stakeManagerV2.assetCustodied());

        vm.prank(admin);
        stakeManagerV2.sweepToCustody(address(0), custody);

        assertTrue(stakeManagerV2.assetCustodied());

        vm.expectRevert(IStakeManagerV2.AssetCustodied.selector);
        stakeManagerV2.redeemBnbxForBnb(1 ether);
    }

    // -------- helpers --------

    function _arm(uint256 delay) internal {
        vm.prank(admin);
        stakeManagerV2.setCustodyDelay(delay);
    }

    function _fundContract(uint256 amount) internal {
        vm.deal(address(stakeManagerV2), address(stakeManagerV2).balance + amount);
    }
}

contract RejectETH {
    receive() external payable {
        revert("no eth");
    }
}
