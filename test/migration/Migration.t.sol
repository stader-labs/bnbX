// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
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
        stakeManagerV2 = StakeManagerV2(payable(_createProxy(address(new StakeManagerV2()))));
        stakeManagerV2.initialize(devAddr, address(operatorRegistry), BNBx, treasury);

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

    function _upgradeAndSetupContracts() private {
        address stakeManagerV1Impl = address(new StakeManager());

        vm.prank(timelock);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(stakeManagerV1)), stakeManagerV1Impl);
    }

    function setUp() public {
        string memory rpcUrl = vm.envString("BSC_MAINNET_RPC_URL");
        vm.createSelectFork(rpcUrl);

        proxyAdmin = 0xF90e293D34a42CB592Be6BE6CA19A9963655673C; // old proxy admin with timelock 0xD990A252E7e36700d47520e46cD2B3E446836488
        timelock = 0xD990A252E7e36700d47520e46cD2B3E446836488;
        admin = 0xb866E12b414d9f975034C4BA51498E6E64559a4c; // external multisig
        manager = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig
        staderOperator = makeAddr("stader-operator");
        treasury = makeAddr("treasury");

        devAddr = address(this); // may change it to your own address

        stakeManagerV1 = StakeManager(payable(0x7276241a669489E4BBB76f63d2A43Bfe63080F2F));

        _deployAndSetupContracts();
        _upgradeAndSetupContracts();
    }

    function test_migrateFunds() public {
        uint256 prevManagerBal = manager.balance;
        uint256 depositsInContractV1 = stakeManagerV1.depositsInContract();

        // admin extracts funds from stake manager v1
        // depositsInContractV1 funds are sent to manager
        vm.startPrank(manager); // internal multisig holds default_admin_role
        stakeManagerV1.togglePause(); // pause stake manager v1
        stakeManagerV1.migrateFunds();
        vm.stopPrank();
        assertEq(manager.balance, prevManagerBal + depositsInContractV1);

        // claimWallet
        address claimWallet = 0xDfB508E262B683EC52D533B80242Ae74087BC7EB;

        // assumption : claim wallet has atleast depositDelegatedV1
        uint256 depositDelegatedV1 = stakeManagerV1.depositsDelegated();
        vm.deal(claimWallet, depositDelegatedV1 + 0.1 ether);

        // claim wallet sends depositDelegatedV1 funds to manager
        vm.prank(claimWallet);
        (bool success,) = payable(manager).call{ value: depositDelegatedV1 }("");
        require(success, "claim_wallet to manager transfer failed");

        // assert manager has right balance
        uint256 prevTVL = stakeManagerV1.getTotalPooledBnb();
        assertEq(manager.balance, prevManagerBal + prevTVL);

        vm.startPrank(manager);
        stakeManagerV2.pause();
        stakeManagerV2.delegateWithoutMinting{ value: prevTVL }();
        vm.stopPrank();

        uint256 er1 = stakeManagerV1.convertBnbXToBnb(1 ether);
        uint256 er2 = stakeManagerV2.convertBnbXToBnb(1 ether);
        console2.log("v1: 1 BNBx to BNB:", er1);
        console2.log("v2: 1 BNBx to BNB:", er2);

        assertEq(er1, er2, "migrate funds failed");

        // set stake Manager on BnbX
        vm.prank(timelock);
        BnbX(BNBx).setStakeManager(address(stakeManagerV2));

        vm.prank(admin);
        stakeManagerV2.unpause();

        // simple delegate test
        address user = makeAddr("user");
        vm.deal(user, 2 ether);

        vm.prank(user);
        stakeManagerV2.delegate{ value: er2 }("referral");

        assertApproxEqAbs(BnbX(BNBx).balanceOf(user), 1 ether, 2);
    }
}
