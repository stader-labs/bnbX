// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { StakeManager } from "contracts/StakeManager.sol";
import { StakeManagerV2 } from "contracts/StakeManagerV2.sol";
import { OperatorRegistry } from "contracts/OperatorRegistry.sol";

contract Migration is Script {
    bytes32 public constant GENERIC_SALT = keccak256(abi.encodePacked("BNBX-MIGRATION"));

    address private proxyAdmin;
    address private admin;
    address private manager;
    address private staderOperator;
    address private treasury;
    address private devAddr;

    // address public STAKE_HUB = 0x0000000000000000000000000000000000002002;
    address private BNBx = 0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275;

    StakeManagerV2 public stakeManagerV2;
    OperatorRegistry public operatorRegistry;

    function _createProxy(address impl) private returns (address proxy) {
        proxy = address(new TransparentUpgradeableProxy{ salt: GENERIC_SALT }(impl, proxyAdmin, ""));
        console2.log("proxy address: ", proxy);
        console2.log("impl address: ", impl);
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
        console2.log("deploying operator registry...");
        operatorRegistry = OperatorRegistry(_createProxy(address(new OperatorRegistry())));
        operatorRegistry.initialize(devAddr);

        // grant manager and operator role for operator registry
        console2.log("granting manager and operator role for operator registry...");
        operatorRegistry.grantRole(operatorRegistry.MANAGER_ROLE(), manager);
        operatorRegistry.grantRole(operatorRegistry.OPERATOR_ROLE(), staderOperator);

        // TODO: done manually
        // // add preferred operator
        // address bscOperator = 0x343dA7Ff0446247ca47AA41e2A25c5Bbb230ED0A;
        // vm.prank(manager);
        // operatorRegistry.addOperator(bscOperator);
        // vm.prank(staderOperator);
        // operatorRegistry.setPreferredDepositOperator(bscOperator);

        // deploy stake manager v2
        console2.log("deploying stake manager v2...");
        // stakeManagerV2 impl
        address stakeManagerV2Impl = address(new StakeManagerV2());

        stakeManagerV2 = StakeManagerV2(payable(_createProxy(stakeManagerV2Impl)));
        stakeManagerV2.initialize(devAddr, address(operatorRegistry), BNBx, treasury);
        operatorRegistry.initialize2(address(stakeManagerV2));

        // grant manager role for stake manager v2
        console2.log("granting manager and operator role for stake manager v2...");
        stakeManagerV2.grantRole(stakeManagerV2.MANAGER_ROLE(), manager);
        stakeManagerV2.grantRole(stakeManagerV2.OPERATOR_ROLE(), staderOperator);

        // grant default admin role to admin
        console2.log("granting default admin role to admin for both contracts...");
        stakeManagerV2.grantRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), admin);
        operatorRegistry.grantRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), admin);

        // renounce DEFAULT_ADMIN_ROLE from devAddr
        console2.log("renouncing default admin role from devAddr...");
        stakeManagerV2.renounceRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), devAddr);
        operatorRegistry.renounceRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), devAddr);

        console2.log("deploying stake manager v1 impl...");
        address stakeManagerV1Impl = address(new StakeManager());
        console2.log("stakeManagerV1Impl: ", stakeManagerV1Impl);
    }

    function run() public {
        proxyAdmin = 0xF90e293D34a42CB592Be6BE6CA19A9963655673C;
        admin = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig
        manager = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig
        staderOperator = 0xDfB508E262B683EC52D533B80242Ae74087BC7EB; // previous claim wallet
        treasury = 0x01422247a1d15BB4FcF91F5A077Cf25BA6460130; // treasury
        devAddr = msg.sender;

        vm.startBroadcast(); // the executer will become msg.sender
        console.log("deploying contracts by: ", msg.sender);
        _deployAndSetupContracts();
        verify();
        vm.stopBroadcast();
        // TODO: assert manually
        // // assert only admin has DEFAULT_ADMIN_ROLE in both the contracts
        // assertTrue(stakeManagerV2.hasRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), admin));
        // assertTrue(operatorRegistry.hasRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), admin));

        // assertFalse(stakeManagerV2.hasRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), devAddr));
        // assertFalse(operatorRegistry.hasRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), devAddr));
    }

    function verify() public view {
        require(
            stakeManagerV2.hasRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), admin),
            "stakeManagerV2 has no DEFAULT_ADMIN_ROLE"
        );
        require(stakeManagerV2.hasRole(stakeManagerV2.MANAGER_ROLE(), manager), "stakeManagerV2 has no MANAGER_ROLE");
        require(
            stakeManagerV2.hasRole(stakeManagerV2.OPERATOR_ROLE(), staderOperator),
            "stakeManagerV2 has no OPERATOR_ROLE"
        );

        require(
            operatorRegistry.hasRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), admin),
            "operatorRegistry has no DEFAULT_ADMIN_ROLE"
        );
        require(
            operatorRegistry.hasRole(operatorRegistry.MANAGER_ROLE(), manager), "operatorRegistry has no MANAGER_ROLE"
        );
        require(
            operatorRegistry.hasRole(operatorRegistry.OPERATOR_ROLE(), staderOperator),
            "operatorRegistry has no OPERATOR_ROLE"
        );

        require(
            !stakeManagerV2.hasRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), devAddr),
            "stakeManagerV2 has DEFAULT_ADMIN_ROLE from devAddr"
        );
        require(
            !operatorRegistry.hasRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), devAddr),
            "operatorRegistry has DEFAULT_ADMIN_ROLE from devAddr"
        );

        require(operatorRegistry.stakeManager() == address(stakeManagerV2), "operatorRegistry has wrong stakeManager");
    }
}
