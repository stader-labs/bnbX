// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {IStakeHub} from "./interfaces/IStakeHub.sol";
import {IBnbX} from "./interfaces/IBnbX.sol";
import "./interfaces/IOperatorRegistry.sol";

contract StakeManagerV2 is AccessControlUpgradeable, PausableUpgradeable {
    // IStakeHub immutable stakeHub;
    // IOperatorRegistry public operatorRegistry;
    // IBnbX public bnbX;

    // /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }

    // function initialize(address _operatorRegistry, address _bnbX)
    //     external
    //     initializer
    // {
    //     stakeHub = IStakeHub(0x0000000000000000000000000000000000002002);
    //     operatorRegistry = IOperatorRegistry(_operatorRegistry);
    //     bnbX = IBnbX(_bnbX);
    // }

    // function delegate() external payable whenNotPaused returns (uint256) {
    //     (uint256 amountToMint, , ) = convertBnbToBnbX(amount);

    //     _mint(depositor, amountToMint);

    //     address preferredOperatorAddress = IOperatorRegistry(operatorRegistry)
    //         .preferredDepositOperatorAddress();
    //     stakeHub.delegate(preferredOperatorAddress){value: msg.value};

    //     emit Delegate(preferredOperatorAddress, msg.value);
    //     return amountToMint;
    // }

    // function undelegate(address operator, uint256 shares) external {
    //     stakeHub.undelegate(operator, shares);
    // }

    // function redelegate(
    //     address srcValidator,
    //     address dstValidator,
    //     uint256 shares
    // ) external {
    //     require(
    //         IValidatorRegistry(validatorRegistry).validatorIdExists(
    //             _fromValidatorId
    //         ),
    //         "From validator id does not exist in our registry"
    //     );
    //     require(
    //         IValidatorRegistry(validatorRegistry).validatorIdExists(
    //             _toValidatorId
    //         ),
    //         "To validator id does not exist in our registry"
    //     );
    //     stakeHub.redelegate(srcValidator, dstValidator, shares);
    // }
}
