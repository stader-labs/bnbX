// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { StakeManager } from "contracts/StakeManager.sol";
import { BnbX } from "contracts/BnbX.sol";
import { StakeManagerV2 } from "contracts/StakeManagerV2.sol";
import { OperatorRegistry } from "contracts/OperatorRegistry.sol";

contract Migration is Test {
    bytes32 public constant GENERIC_SALT = keccak256(abi.encodePacked("BNBX-MIGRATION"));

    address public proxyAdmin;
    address public timelock;
    address public admin;
    address public manager;
    address public staderOperator;

    address public treasury;
    address public devAddr;

    address public STAKE_HUB = 0x0000000000000000000000000000000000002002;
    address public BNBx = 0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275;

    StakeManager public stakeManagerV1;
    StakeManagerV2 public stakeManagerV2;
    OperatorRegistry public operatorRegistry;

    function _createProxy(address impl) private returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy{ salt: GENERIC_SALT }(impl, proxyAdmin, ""));
    }

    /// @dev Computes the address of a proxy for the given implementation
    /// @param implementation the implementation to proxy
    /// @return proxyAddr the address of the created proxy
    function _computeAddress(address implementation) private view returns (address) {
        bytes memory creationCode = type(TransparentUpgradeableProxy).creationCode;
        bytes memory contractBytecode = abi.encodePacked(creationCode, abi.encode(implementation, proxyAdmin, ""));

        return Create2.computeAddress(GENERIC_SALT, keccak256(contractBytecode));
    }

    function _deployAndSetupContracts() private {
        // deploy operator registry
        operatorRegistry = OperatorRegistry(_createProxy(address(new OperatorRegistry())));
        operatorRegistry.initialize(devAddr);

        // grant manager and operator role for operator registry
        vm.startPrank(devAddr);
        operatorRegistry.grantRole(operatorRegistry.MANAGER_ROLE(), manager);
        operatorRegistry.grantRole(operatorRegistry.OPERATOR_ROLE(), staderOperator);
        vm.stopPrank();

        // add preferred operator
        address bscOperator = 0x343dA7Ff0446247ca47AA41e2A25c5Bbb230ED0A;
        vm.prank(manager);
        operatorRegistry.addOperator(bscOperator);
        vm.prank(staderOperator);
        operatorRegistry.setPreferredDepositOperator(bscOperator);

        // deploy stake manager v2
        // stakeManagerV2 impl
        address stakeManagerV2Impl = address(new StakeManagerV2());
        stakeManagerV2 = StakeManagerV2(payable(_createProxy(stakeManagerV2Impl)));
        stakeManagerV2.initialize(devAddr, address(operatorRegistry), BNBx, treasury);
        operatorRegistry.initialize2(address(stakeManagerV2));

        assertEq(operatorRegistry.stakeManager(), address(stakeManagerV2));

        vm.startPrank(devAddr);
        // grant manager role for stake manager v2
        stakeManagerV2.grantRole(stakeManagerV2.MANAGER_ROLE(), manager);
        stakeManagerV2.grantRole(stakeManagerV2.OPERATOR_ROLE(), staderOperator);

        // grant default admin role to admin
        stakeManagerV2.grantRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), admin);
        operatorRegistry.grantRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), admin);

        // renounce DEFAULT_ADMIN_ROLE from devAddr
        stakeManagerV2.renounceRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), devAddr);
        operatorRegistry.renounceRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), devAddr);

        vm.stopPrank();

        // assert only admin has DEFAULT_ADMIN_ROLE in both the contracts
        assertTrue(stakeManagerV2.hasRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(operatorRegistry.hasRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), admin));

        assertFalse(stakeManagerV2.hasRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), devAddr));
        assertFalse(operatorRegistry.hasRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), devAddr));
    }

    function _upgradeStakeManagerV1() private {
        address stakeManagerV1Impl = 0x410ef6738C98c9478C7d21eF948a6dfd0FA9ED45;

        vm.prank(timelock);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(stakeManagerV1)), stakeManagerV1Impl);
    }

    function setUp() public {
        string memory rpcUrl = vm.envString("BSC_MAINNET_RPC_URL");
        vm.createSelectFork(rpcUrl);

        proxyAdmin = 0xF90e293D34a42CB592Be6BE6CA19A9963655673C; // old proxy admin with timelock 0xD990A252E7e36700d47520e46cD2B3E446836488
        timelock = 0xD990A252E7e36700d47520e46cD2B3E446836488;
        admin = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig
        manager = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig
        staderOperator = 0xDfB508E262B683EC52D533B80242Ae74087BC7EB;
        treasury = 0x01422247a1d15BB4FcF91F5A077Cf25BA6460130;

        devAddr = address(this); // may change it to your own address

        stakeManagerV1 = StakeManager(payable(0x7276241a669489E4BBB76f63d2A43Bfe63080F2F));
        operatorRegistry = OperatorRegistry(0x9C1759359Aa7D32911c5bAD613E836aEd7c621a8);
        stakeManagerV2 = StakeManagerV2(payable(0x3b961e83400D51e6E1AF5c450d3C7d7b80588d28));
        // _deployAndSetupContracts();
    }

    function test_migrateFunds() public {
        // add preferred operator
        address bscOperator = 0x343dA7Ff0446247ca47AA41e2A25c5Bbb230ED0A;
        vm.startPrank(manager);
        operatorRegistry.addOperator(bscOperator);
        stakeManagerV2.pause();
        vm.stopPrank();

        vm.startPrank(staderOperator);
        operatorRegistry.setPreferredDepositOperator(bscOperator);
        operatorRegistry.setPreferredWithdrawalOperator(bscOperator);
        vm.stopPrank();

        address userV1 = makeAddr("userV1");
        // user gets some bnbx
        startHoax(userV1, 10 ether);
        stakeManagerV1.deposit{ value: 10 ether }();

        // some user requests withdraw
        BnbX(BNBx).approve(address(stakeManagerV1), 8 ether);
        stakeManagerV1.requestWithdraw(8 ether);
        vm.stopPrank();

        assertEq(stakeManagerV1.getUserWithdrawalRequests(userV1).length, 1); // 1 request raised
        (bool isClaimable,) = stakeManagerV1.getUserRequestStatus(userV1, 0);
        assertFalse(isClaimable); // not claimable

        // claimWallet or staderOperator should have unstaked and rcvd all funds
        uint256 stakedFunds = (5760.8394 ether + 5013.0108 ether + 5012.5161 ether + 3512.3595 ether + 19.8107 ether);
        vm.deal(staderOperator, staderOperator.balance + stakedFunds);
        // manager processes pending withdraw batch
        vm.startPrank(staderOperator);
        (uint256 uuid, uint256 batchAmountInBNB) = stakeManagerV1.startUndelegation();
        stakeManagerV1.undelegationStarted(uuid);
        stakeManagerV1.completeUndelegation{ value: batchAmountInBNB }(uuid);
        vm.stopPrank();

        (isClaimable,) = stakeManagerV1.getUserRequestStatus(userV1, 0);
        assertTrue(isClaimable); // claimable

        uint256 prevManagerBal = manager.balance;
        uint256 depositsInContractV1 = stakeManagerV1.depositsInContract();

        _upgradeStakeManagerV1(); // --------- EXECUTE TXN 6 on TIMELOCK -------------------- //

        // admin extracts funds from stake manager v1
        vm.startPrank(admin); // internal multisig holds default_admin_role
        stakeManagerV1.togglePause(); // pause stakeManagerV1
        stakeManagerV1.migrateFunds(); // depositsInContractV1 funds are sent to manager
        vm.stopPrank();
        assertEq(manager.balance, prevManagerBal + depositsInContractV1);

        // assumption : claim wallet should have atleast depositDelegatedV1
        uint256 depositDelegatedV1 = stakeManagerV1.depositsDelegated();

        // claim wallet (staderOperator) sends depositDelegatedV1 funds to manager
        vm.prank(staderOperator);
        (bool success,) = payable(manager).call{ value: depositDelegatedV1 }("");
        require(success, "claim_wallet to manager transfer failed");

        // assert manager has right balance
        uint256 prevTVL = stakeManagerV1.getTotalPooledBnb();
        assertEq(manager.balance, prevManagerBal + prevTVL);

        vm.startPrank(manager);
        stakeManagerV2.delegateWithoutMinting{ value: prevTVL }();
        vm.stopPrank();

        uint256 er1 = stakeManagerV1.convertBnbXToBnb(1 ether);
        uint256 er2 = stakeManagerV2.convertBnbXToBnb(1 ether);
        console2.log("v1: 1 BNBx to BNB:", er1);
        console2.log("v2: 1 BNBx to BNB:", er2);
        console2.log("claim wallet balance left:", staderOperator.balance);
        assertEq(er1, er2, "migrate funds failed");

        // set stake Manager on BnbX // --------- EXECUTE TXN 7 on TIMELOCK -------------------- //
        vm.prank(timelock);
        BnbX(BNBx).setStakeManager(address(stakeManagerV2));

        vm.prank(admin);
        stakeManagerV2.unpause();

        // simple delegate test on stakeManagerV2
        address userV2 = makeAddr("userV2");
        vm.deal(userV2, 2 ether);

        vm.prank(userV2);
        stakeManagerV2.delegate{ value: er2 }("referral");
        assertApproxEqAbs(BnbX(BNBx).balanceOf(userV2), 1 ether, 2);

        // previous user1 claims from v1
        vm.prank(userV1);
        stakeManagerV1.claimWithdraw(0);
    }
}
