// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IPoolWrapper {
    function swap(address pool, bytes calldata data) external returns (uint256 amountOut);

    function getPoolVault(address pool) external view returns (address);

    function getAmountIn(address pool, address tokenOut, uint256 amountOut) external view returns (uint256 amountIn);

    function getAmountOut(address pool, address tokenIn, uint256 amountIn) external view returns (uint256 amountOut);

    function token0(address pool) external view returns (address);

    function token1(address pool) external view returns (address);

    function getReserves(address pool) external view returns (uint, uint);
}
