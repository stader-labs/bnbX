// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/// @title BnbX interface
interface IBnbX is IERC20Upgradeable {
    function initialize() external;

    function mint(address _to, uint256 _amount) external;

    function burn(address _to, uint256 _amount) external;
}
