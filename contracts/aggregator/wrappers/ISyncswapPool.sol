// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../common/TokenTransferer.sol";
import "../IPoolWrapper.sol";

interface ISyncswapPool {
    struct TokenAmount {
        address token;
        uint amount;
    }

    function vault() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint, uint);

    function getAmountOut(address tokenIn, uint amountIn, address sender) external view returns (uint amountOut);

    function getAmountIn(address tokenOut, uint amountOut, address sender) external view returns (uint amountIn);

    function swap(
        bytes calldata data,
        address sender,
        address callback,
        bytes calldata callbackData
    ) external returns (TokenAmount memory tokenAmount);
}
