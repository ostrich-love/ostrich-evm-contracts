// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);
}

contract FeeCollector is OwnableUpgradeable {
    struct FeeConfig {
        uint256 burnFee;
        uint256 gov1Fee;
        uint256 gov2Fee;
        uint256 liquidityFee;
        uint256 jackpotFee;
        uint256 bonusFee;
        uint256 devFee;
        uint256 totalFee;
    }
    FeeConfig private _sellFee;
    FeeConfig private _buyFee;

    function initialize() public initializer {
        __Ownable_init();
    }

    function getFee(address token, address from, address to, uint256 amount) external returns (uint256 fee) {}

    function takeFee(address token, address from, address to) external {
        uint256 totalFee = IERC20(token).balanceOf(address(this));
    }
}
