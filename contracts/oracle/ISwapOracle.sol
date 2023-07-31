// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "./IOracle.sol";

interface ISwapOracle is IOracle {
    function updatePrice(address token0, address token1) external;

    function queryAverageAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function queryInstantAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 tokenAmountIn
    ) external view returns (uint256 tokenAmountOut);

    function queryTokenPrices(address[] memory tokens) external view returns (uint256[] memory);

    function queryPairPrices(address[] memory pairs) external view returns (uint256[] memory);

    function queryTokenPrice(address token) external view returns (uint256);

    function queryPairPrice(address pairAddress) external view returns (uint256);
}
