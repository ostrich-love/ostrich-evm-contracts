// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IOracle {
    function queryPrice(address asset) external view returns (uint256 price);
}
