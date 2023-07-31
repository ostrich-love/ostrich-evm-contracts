// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISwapObserver {
    function onSwap(
        address pool,
        address trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) external;
}
