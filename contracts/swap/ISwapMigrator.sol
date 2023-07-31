// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISwapMigrator {
    function desiredLiquidity() external view returns (uint256);
}
