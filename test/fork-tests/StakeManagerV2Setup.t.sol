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
import "contracts/StakeManagerV2.sol";
import { OperatorRegistry, IOperatorRegistry } from "contracts/OperatorRegistry.sol";
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

        _clearCurrentPendingTransactions();
    }

    // ----------------------------------HELPERS-------------------------------- //

    function _initialiseAddresses() private {
        // TODO: update below addresses with correct addresses once on mainnet
        proxyAdmin = 0xF90e293D34a42CB592Be6BE6CA19A9963655673C;
        timelock = 0xD990A252E7e36700d47520e46cD2B3E446836488;
        admin = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig
        manager = 0x79A2Ae748AC8bE4118B7a8096681B30310c3adBE; // internal multisig
        staderOperator = 0xDfB508E262B683EC52D533B80242Ae74087BC7EB;
        treasury = 0x01422247a1d15BB4FcF91F5A077Cf25BA6460130;

        devAddr = address(this); // may change it to your own address
        stakeManagerV1 = StakeManager(payable(0x7276241a669489E4BBB76f63d2A43Bfe63080F2F));
        stakeManagerV2 = StakeManagerV2(payable(0x3b961e83400D51e6E1AF5c450d3C7d7b80588d28));
        operatorRegistry = OperatorRegistry(0x9C1759359Aa7D32911c5bAD613E836aEd7c621a8);

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
    }

    function _clearCurrentPendingTransactions() private {
        // clear current withdrawals from preferred current withdrawal operator
        address oldWithdrawOperator = operatorRegistry.preferredWithdrawalOperator();
        uint256 numWithdrawRequests = stakeManagerV2.getUnprocessedWithdrawalRequestCount();
        vm.prank(staderOperator);
        stakeManagerV2.startBatchUndelegation(numWithdrawRequests, oldWithdrawOperator);

        skip(8 days);

        uint256 numUnbondingBatches =
            stakeManagerV2.getBatchWithdrawalRequestCount() - stakeManagerV2.firstUnbondingBatchIndex();
        while (numUnbondingBatches > 0) {
            stakeManagerV2.completeBatchUndelegation();
            numUnbondingBatches--;
        }
    }

    function _upgradeAndSetupContracts() private {
        address stakeManagerV1Impl = address(new StakeManager());

        vm.prank(timelock);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(stakeManagerV1)), stakeManagerV1Impl);
    }

    function _deployAndSetupContracts() private {
        // stakeManagerV2 impl
        address stakeManagerV2Impl = address(new StakeManagerV2());

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
        stakeManagerV2 = StakeManagerV2(payable(_createProxy(stakeManagerV2Impl)));
        stakeManagerV2.initialize(devAddr, address(operatorRegistry), bnbxAddr, treasury);
        operatorRegistry.initialize2(address(stakeManagerV2));
        assertEq(address(stakeManagerV2), operatorRegistry.stakeManager());

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

    /// @dev Computes the address of a proxy for the given implementation
    /// @param implementation the implementation to proxy
    /// @return proxyAddr the address of the created proxy
    function _computeAddress(address implementation) private view returns (address) {
        bytes memory creationCode = type(TransparentUpgradeableProxy).creationCode;
        bytes memory contractBytecode = abi.encodePacked(creationCode, abi.encode(implementation, proxyAdmin, ""));

        return Create2.computeAddress(GENERIC_SALT, keccak256(contractBytecode));
    }

    function _bnbxBalance(address addr) internal view returns (uint256) {
        return BnbX(bnbxAddr).balanceOf(addr);
    }
}
