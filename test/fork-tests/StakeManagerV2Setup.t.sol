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
import { IStakeHub } from "contracts/interfaces/IStakeHub.sol";

contract StakeManagerV2Setup is Test {
    bytes32 public constant GENERIC_SALT = keccak256(abi.encodePacked("BNBX-MIGRATION"));

    address public proxyAdmin;
    address public timelock;
    address public admin;
    address public manager;
    address public staderOperator;
    address public treasury;
    address public devAddr;
    address public user1;
    address public user2;

    IStakeHub public STAKE_HUB = IStakeHub(0x0000000000000000000000000000000000002002);
    address public bnbxAddr = 0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275;

    StakeManager public stakeManagerV1;
    StakeManagerV2 public stakeManagerV2;
    OperatorRegistry public operatorRegistry;

    function setUp() public virtual {
        string memory rpcUrl = vm.envString("BSC_MAINNET_RPC_URL");
        vm.createSelectFork(rpcUrl);

        _initialiseAddresses();

        // TODO: remove below 3 lines, after successful migration
        _deployAndSetupContracts();
        _upgradeAndSetupContracts();
        _migrateFunds();
    }

    // ----------------------------------HELPERS-------------------------------- //

    function _initialiseAddresses() private {
        // TODO: update below addresses with correct addresses once on mainnet
        proxyAdmin = 0xF90e293D34a42CB592Be6BE6CA19A9963655673C;
        timelock = 0xD990A252E7e36700d47520e46cD2B3E446836488;
        admin = 0xb866E12b414d9f975034C4BA51498E6E64559a4c; // external multisig
        manager = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig
        staderOperator = makeAddr("stader-operator");
        treasury = makeAddr("treasury");

        devAddr = address(this); // may change it to your own address
        stakeManagerV1 = StakeManager(payable(0x7276241a669489E4BBB76f63d2A43Bfe63080F2F));
        // stakeManagerV2 = StakeManagerV2(0x...);
        // operatorRegistry = OperatorRegistry(0x...);

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
    }

    function _upgradeAndSetupContracts() private {
        address stakeManagerV1Impl = address(new StakeManager());

        vm.prank(timelock);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(stakeManagerV1)), stakeManagerV1Impl);
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
        vm.startPrank(staderOperator);
        operatorRegistry.setPreferredDepositOperator(bscOperator);
        operatorRegistry.setPreferredWithdrawalOperator(bscOperator);
        vm.stopPrank();

        // deploy stake manager v2
        stakeManagerV2 = StakeManagerV2(payable(_createProxy(address(new StakeManagerV2()))));
        stakeManagerV2.initialize(devAddr, address(operatorRegistry), bnbxAddr, treasury);

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

    function _createProxy(address impl) private returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy{ salt: GENERIC_SALT }(impl, proxyAdmin, ""));
    }

    function _migrateFunds() private {
        uint256 prevTVL = stakeManagerV1.getTotalPooledBnb();
        vm.deal(manager, prevTVL);

        vm.startPrank(manager);
        stakeManagerV1.togglePause();
        stakeManagerV2.pause();
        stakeManagerV2.delegateWithoutMinting{ value: prevTVL }();
        vm.stopPrank();

        // set stake Manager on BnbX
        vm.prank(timelock);
        BnbX(bnbxAddr).setStakeManager(address(stakeManagerV2));

        vm.prank(admin);
        stakeManagerV2.unpause();
    }
}
