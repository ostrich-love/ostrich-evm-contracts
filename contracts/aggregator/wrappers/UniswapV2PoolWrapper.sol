// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../IPoolWrapper.sol";

interface ISwapPair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract UniswapV2PoolWrapper is IPoolWrapper, OwnableUpgradeable {
    function initialize() public initializer {
        __Ownable_init();
    }

    function getPoolVault(address pool) public pure override returns (address) {
        return pool;
    }

    function swap(address pool, bytes calldata data_) external override returns (uint256 amountOut) {
        (address tokenIn, uint256 amountIn, address to) = abi.decode(data_, (address, uint256, address));
        ISwapPair p = ISwapPair(pool);
        amountOut = getAmountOut(pool, tokenIn, amountIn);
        (address t0, address t1) = (p.token0(), p.token1());
        if (tokenIn == t0) {
            p.swap(0, amountOut, to, "");
        } else if (tokenIn == t1) {
            p.swap(amountOut, 0, to, "");
        } else {
            revert("INVALID_PAIR");
        }
    }

    function getAmountIn(
        address pair,
        address tokenOut,
        uint256 amountOut
    ) public view override returns (uint256 amountIn) {
        (uint256 _reserve0, uint256 _reserve1) = getReserves(pair);
        if (tokenOut == ISwapPair(pair).token0()) {
            return _getAmountIn(amountOut, _reserve1, _reserve0);
        } else {
            return _getAmountIn(amountOut, _reserve0, _reserve1);
        }
    }

    function getAmountOut(
        address pair,
        address tokenIn,
        uint256 amountIn
    ) public view override returns (uint256 amountOut) {
        (uint256 _reserve0, uint256 _reserve1) = getReserves(pair);
        if (tokenIn == ISwapPair(pair).token0()) {
            return _getAmountOut(amountIn, _reserve0, _reserve1);
        } else {
            return _getAmountOut(amountIn, _reserve1, _reserve0);
        }
    }

    function token0(address pair) public view override returns (address) {
        return ISwapPair(pair).token0();
    }

    function token1(address pair) public view override returns (address) {
        return ISwapPair(pair).token1();
    }

    function getReserves(address pair) public view override returns (uint, uint) {
        (uint112 _reserve0, uint112 _reserve1, ) = ISwapPair(pair).getReserves();
        return (uint256(_reserve0), uint256(_reserve1));
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "UniswapV2PoolWrapper: TRANSFER_FAILED");
    }

    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB) private pure returns (uint256 amountB) {
        require(amountA > 0, "UniswapV2PoolWrapper: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "UniswapV2PoolWrapper: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * (reserveB)) / reserveA;
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) private pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2PoolWrapper: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2PoolWrapper: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * (997);
        uint256 numerator = amountInWithFee * (reserveOut);
        uint256 denominator = reserveIn * (1000) + (amountInWithFee);
        amountOut = numerator / denominator;
    }

    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) private pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2PoolWrapper: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2PoolWrapper: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * (amountOut) * (1000);
        uint256 denominator = reserveOut - (amountOut) * (997);
        amountIn = (numerator / denominator) + (1);
    }
}
