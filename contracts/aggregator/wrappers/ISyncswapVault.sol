// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISyncswapVault {
    function deposit(address token, address to) external payable;

    function balanceOf(address token, address owner) external view returns (uint balance);
}
