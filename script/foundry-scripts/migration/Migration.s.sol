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
        // stakeManagerV2 impl
        address stakeManagerV2Impl = address(new StakeManagerV2());

        // compute stakeManagerV2 proxy address
        address stakeManagerV2Proxy = _computeAddress(stakeManagerV2Impl);

        // deploy operator registry
        console2.log("deploying operator registry...");
        OperatorRegistry operatorRegistry = OperatorRegistry(_createProxy(address(new OperatorRegistry())));
        operatorRegistry.initialize(devAddr, stakeManagerV2Proxy);

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
        StakeManagerV2 stakeManagerV2 = StakeManagerV2(payable(_createProxy(stakeManagerV2Impl)));
        stakeManagerV2.initialize(devAddr, address(operatorRegistry), BNBx, treasury);

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
        proxyAdmin = 0xF90e293D34a42CB592Be6BE6CA19A9963655673C; // TODO: check if needs to be changed ?
        admin = 0xb866E12b414d9f975034C4BA51498E6E64559a4c; // external multisig , TODO: check if needs to be changed ?
        manager = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig, TODO: check if needs to be changed ?
        staderOperator = makeAddr("stader-operator"); // TODO
        treasury = makeAddr("treasury"); // TODO
        devAddr = msg.sender;

        vm.startBroadcast(); // the executer will become msg.sender
        console.log("deploying contracts by: ", msg.sender);
        _deployAndSetupContracts();
        vm.stopBroadcast();

        // TODO: assert manually
        // // assert only admin has DEFAULT_ADMIN_ROLE in both the contracts
        // assertTrue(stakeManagerV2.hasRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), admin));
        // assertTrue(operatorRegistry.hasRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), admin));

        // assertFalse(stakeManagerV2.hasRole(stakeManagerV2.DEFAULT_ADMIN_ROLE(), devAddr));
        // assertFalse(operatorRegistry.hasRole(operatorRegistry.DEFAULT_ADMIN_ROLE(), devAddr));
    }
}
