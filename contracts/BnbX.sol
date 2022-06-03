// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./interfaces/IBnbX.sol";

contract BnbX is IBnbX, ERC20Upgradeable {
    function mint(address _to, uint256 _amount) external override {
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) external override {
        _burn(_to, _amount);
    }
}
