// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IPoolWrapper.sol";

interface IDexAggregator {
    struct Pool {
        address a;
        uint8 t;
    }

    function getAmountOut(
        Pool[] memory pools,
        address tokenIn,
        uint256 amountIn
    ) external view returns (address tokenOut, uint256 amountOut);

    function swap(
        Pool[] memory pools,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external payable;

    function getWrapper(uint8 poolType) external view returns (IPoolWrapper);
}
