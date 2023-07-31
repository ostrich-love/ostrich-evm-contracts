// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISwapAggregator {
    event SWAP(
        address indexed sender,
        address[] path,
        uint256 amountIn,
        uint256 amountOut,
        address to,
        uint256 timestamp
    );

    function getAmountOut(
        address[] calldata path,
        uint256 tokenAmountIn
    ) external view returns (uint256 tokenAmountOut);

    function getAmountIn(address[] calldata path, uint256 tokenAmountOut) external view returns (uint256 tokenAmountIn);

    function swapExactTokenForToken(
        address[] calldata tokenPath,
        uint256 tokenAmountIn,
        uint256 tokenAmountOutMin,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokenForTokenSupportingFeeOnTransferTokens(
        address[] calldata tokenPath,
        uint256 tokenAmountIn,
        uint256 tokenAmountOutMin,
        address to,
        uint256 deadline
    ) external payable;

    function swapTokenForExactToken(
        address[] calldata tokenPath,
        uint256 tokenAmountInMax,
        uint256 tokenAmountOut,
        address to,
        uint256 deadline
    ) external payable;
}
