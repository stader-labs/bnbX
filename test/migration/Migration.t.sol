// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ProxyFactory } from "utils/deploy-utils/ProxyFactory.sol";

import { StakeManager } from "contracts/StakeManager.sol";
import { StakeManagerV2 } from "contracts/StakeManagerV2.sol";
import { OperatorRegistry } from "contracts/OperatorRegistry.sol";

contract MigrationTest is Test {
    bytes32 public constant GENERIC_SALT = keccak256(abi.encodePacked("BNBX-MIGRATION"));

    ProxyFactory public proxyFactory;
    ProxyAdmin public proxyAdmin;
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

    function _createProxy(address impl) private returns (address) {
        return proxyFactory.create(impl, address(proxyAdmin), GENERIC_SALT);
    }

    function _deployAndSetupContracts() public {
        // deploy operator registry
        operatorRegistry = OperatorRegistry(_createProxy(address(new OperatorRegistry())));
        operatorRegistry.initialize(admin);

        // grant manager role to operator registry
        vm.startPrank(admin);
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
        stakeManagerV2 = StakeManagerV2(_createProxy(address(new StakeManagerV2())));
        stakeManagerV2.initialize(
            admin,
            address(operatorRegistry),
            BNBx,
            treasury,
            100 // uint256 _feeBps
        );

        // grant manager role to stake manager v2
        vm.startPrank(admin);
        stakeManagerV2.grantRole(stakeManagerV2.MANAGER_ROLE(), manager);
        vm.stopPrank();
    }

    function setUp() public {
        string memory rpcUrl = vm.envString("BSC_MAINNET_RPC_URL");
        vm.createSelectFork(rpcUrl);

        admin = makeAddr("admin");
        manager = makeAddr("manager");
        staderOperator = makeAddr("stader-operator");
        treasury = makeAddr("treasury");

        devAddr = makeAddr("dev"); // may change it to your own address
        proxyFactory = new ProxyFactory();

        vm.prank(admin);
        proxyAdmin = new ProxyAdmin(); // msg.sender becomes the owner of ProxyAdmin

        stakeManagerV1 = StakeManager(payable(0x7276241a669489E4BBB76f63d2A43Bfe63080F2F));

        _deployAndSetupContracts();
    }

    function test_migrateFunds() public {
        uint256 prevTVL = stakeManagerV1.getTotalPooledBnb();
        // bring funds to manager
        vm.deal(manager, prevTVL);

        vm.prank(manager);
        stakeManagerV2.delegateWithoutMinting{ value: prevTVL }();

        uint256 er1 = stakeManagerV1.convertBnbXToBnb(1 ether);
        uint256 er2 = stakeManagerV2.convertBnbXToBnb(1 ether);
        console2.log("v1: 1 BNBx to BNB:", er1);
        console2.log("v2: 1 BNBx to BNB:", er2);

        assertEq(er1, er2, "migrate funds failed");
    }
}
