// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./StakeManagerV2Setup.t.sol";

import { ITransparentUpgradeableProxy } from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @dev Fork tests for the custody sweep mechanism added to `StakeManagerV2`.
/// The production proxy still points at the pre-custody impl, so each test
/// first upgrades the proxy to a freshly deployed impl that contains the new
/// state vars + functions.
contract StakeManagerV2Custody is StakeManagerV2Setup {
    address internal custody;
    address internal attacker;

    event SetCustodyDelay(uint256 _custodyDelay, uint256 _custodyConfigTimestamp);
    event Swept(address indexed _custody, uint256 _amount);

    function setUp() public override {
        super.setUp();
        custody = makeAddr("custody");
        attacker = makeAddr("attacker");
        _upgradeToCustodyImpl();
    }

    // -------- access control --------

    function test_setCustodyDelay_revertsForNonManager() public {
        vm.expectRevert();
        vm.prank(attacker);
        stakeManagerV2.setCustodyDelay(1 days);
    }

    function test_sweepToCustody_revertsForNonManager() public {
        _arm(1 days);
        skip(1 days);
        _fundContract(1 ether);

        vm.expectRevert();
        vm.prank(attacker);
        stakeManagerV2.sweepToCustody(custody, 1 ether);
    }

    // -------- setCustodyDelay --------

    function test_setCustodyDelay_setsValuesAndEmits() public {
        uint256 delay = 7 days;

        vm.expectEmit(false, false, false, true);
        emit SetCustodyDelay(delay, block.timestamp);

        vm.prank(manager);
        stakeManagerV2.setCustodyDelay(delay);

        assertEq(stakeManagerV2.custodyDelay(), delay);
        assertEq(stakeManagerV2.custodyConfigTimestamp(), block.timestamp);
    }

    function test_setCustodyDelay_reconfigRestartsClock() public {
        _arm(7 days);
        skip(6 days);

        uint256 t1 = block.timestamp;
        vm.prank(manager);
        stakeManagerV2.setCustodyDelay(7 days);

        assertEq(stakeManagerV2.custodyConfigTimestamp(), t1);

        _fundContract(1 ether);

        skip(6 days);
        vm.prank(manager);
        vm.expectRevert(IStakeManagerV2.CustodyDelayNotElapsed.selector);
        stakeManagerV2.sweepToCustody(custody, 1 ether);

        skip(1 days);
        vm.prank(manager);
        stakeManagerV2.sweepToCustody(custody, 1 ether);
        assertEq(custody.balance, 1 ether);
    }

    // -------- sweepToCustody negative paths --------

    function test_sweepToCustody_revertsBeforeArming() public {
        _fundContract(1 ether);

        vm.prank(manager);
        vm.expectRevert(IStakeManagerV2.CustodyDelayNotConfigured.selector);
        stakeManagerV2.sweepToCustody(custody, 1 ether);
    }

    function test_sweepToCustody_revertsBeforeDelayElapsed() public {
        _arm(7 days);
        _fundContract(1 ether);
        skip(6 days);

        vm.prank(manager);
        vm.expectRevert(IStakeManagerV2.CustodyDelayNotElapsed.selector);
        stakeManagerV2.sweepToCustody(custody, 1 ether);
    }

    function test_sweepToCustody_revertsOnZeroCustody() public {
        _arm(1 days);
        skip(1 days);
        _fundContract(1 ether);

        vm.prank(manager);
        vm.expectRevert(IStakeManagerV2.ZeroAddress.selector);
        stakeManagerV2.sweepToCustody(address(0), 1 ether);
    }

    function test_sweepToCustody_revertsOnZeroAmount() public {
        _arm(1 days);
        skip(1 days);
        _fundContract(1 ether);

        vm.prank(manager);
        vm.expectRevert(IStakeManagerV2.ZeroAmount.selector);
        stakeManagerV2.sweepToCustody(custody, 0);
    }

    // -------- sweepToCustody happy path --------

    function test_sweepToCustody_movesFundsAndEmits() public {
        _arm(1 days);
        skip(1 days);
        _fundContract(5 ether);

        uint256 preBal = address(stakeManagerV2).balance;
        uint256 preCustody = custody.balance;

        vm.expectEmit(true, false, false, true);
        emit Swept(custody, 2 ether);

        vm.prank(manager);
        stakeManagerV2.sweepToCustody(custody, 2 ether);

        assertEq(custody.balance, preCustody + 2 ether);
        assertEq(address(stakeManagerV2).balance, preBal - 2 ether);
    }

    function test_sweepToCustody_partialThenRemainder() public {
        _arm(1 days);
        skip(1 days);
        _fundContract(3 ether);

        vm.startPrank(manager);
        stakeManagerV2.sweepToCustody(custody, 1 ether);
        stakeManagerV2.sweepToCustody(custody, 2 ether);
        vm.stopPrank();

        assertEq(custody.balance, 3 ether);
    }

    // -------- helpers --------

    function _arm(uint256 delay) internal {
        vm.prank(manager);
        stakeManagerV2.setCustodyDelay(delay);
    }

    function _fundContract(uint256 amount) internal {
        vm.deal(address(stakeManagerV2), address(stakeManagerV2).balance + amount);
    }

    function _upgradeToCustodyImpl() internal {
        address newImpl = address(new StakeManagerV2());
        vm.prank(timelock);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(stakeManagerV2)), newImpl);
    }
}
