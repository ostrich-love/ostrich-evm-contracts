// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./libraries/SwapLibrary.sol";
import "./ISwapPair.sol";
import "./ISwapAggregator.sol";
import "./IWETH.sol";
import "./libraries/TransferHelper.sol";
import "./ISwapObserver.sol";

contract SwapAggregator is OwnableUpgradeable, ISwapAggregator {
    address public WETH;

    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => mapping(address => address)) private _pairs;
    EnumerableSet.AddressSet private _pairAddresses;
    address public swapObserver;

    function initialize(address weth) public initializer {
        __Ownable_init();
        WETH = weth;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "SwapAggregator: EXPIRED");
        _;
    }

    receive() external payable {}

    function updateSwapObserver(address val) public onlyOwner {
        swapObserver = val;
    }

    function registerPairs(
        address[] memory token0s,
        address[] memory token1s,
        address[] memory pairs
    ) public onlyOwner {
        require(token0s.length == token1s.length, "SwapAggregator: INVALID_PARAMETERS");
        require(token0s.length == pairs.length, "SwapAggregator: INVALID_PARAMETERS");
        for (uint256 i; i < token0s.length; i++) {
            (address token0, address token1, address pair) = (token0s[i], token1s[i], pairs[i]);
            require(token0 != address(0), "SwapAggregator: TOKEN0_EMPTY");
            require(token1 != address(0), "SwapAggregator: TOKEN1_EMPTY");
            require(token0 != token1, "SwapAggregator: TOKEN0_EQUALS_TOKEN1");
            _pairs[token0][token1] = pair;
            _pairs[token1][token0] = pair;
            _pairAddresses.add(pair);
        }
    }

    function revokePairs(address[] calldata tokenAs, address[] calldata tokenBs) external onlyOwner {
        require(tokenAs.length == tokenBs.length, "SwapAggregator: INVALID_PARAMETERS");
        for (uint256 i; i < tokenAs.length; i++) {
            (address tokenA, address tokenB) = (tokenAs[i], tokenBs[i]);
            address pairAddress = _pairs[tokenA][tokenB];
            delete _pairs[tokenA][tokenB];
            delete _pairs[tokenB][tokenA];
            _pairAddresses.remove(pairAddress);
        }
    }

    function parseTokenPath(address[] memory tokenPath) private view returns (address[] memory pairPath) {
        require(tokenPath.length > 1, "SwapAggregator: INVALID_PATH");
        pairPath = new address[](tokenPath.length - 1);
        for (uint256 i; i < tokenPath.length; i++) {
            address token0 = tokenPath[i] == address(0) ? WETH : tokenPath[i];
            if (i < tokenPath.length - 1) {
                address token1 = tokenPath[i + 1] == address(0) ? WETH : tokenPath[i + 1];
                address pair = _pairs[token0][token1];
                require(pair != address(0), "SwapAggregator: PAIR_NOT_REGISTERED");
                pairPath[i] = pair;
            }
        }
    }

    function getAmountOut(
        address[] calldata tokenPath,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        address[] memory pairPath = parseTokenPath(tokenPath);
        return _getAmountOut(tokenPath, pairPath, amountIn);
    }

    function getAmountIn(
        address[] calldata tokenPath,
        uint256 amountOut
    ) external view override returns (uint256 amountIn) {
        address[] memory pairPath = parseTokenPath(tokenPath);
        return _getAmountIn(tokenPath, pairPath, amountOut);
    }

    function swapExactTokenForToken(
        address[] calldata tokenPath,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) {
        address[] memory pairPath = parseTokenPath(tokenPath);
        uint256 amountOut = _getAmountOut(tokenPath, pairPath, amountIn);
        require(amountOut >= amountOutMin, "SwapAggregator: INSUFFICIENT_OUTPUT_AMOUNT");
        _transferTokenIn(tokenPath, pairPath, amountIn);
        _swap(tokenPath, pairPath, amountIn, to);
    }

    function swapExactTokenForTokenSupportingFeeOnTransferTokens(
        address[] calldata tokenPath,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) {
        address[] memory pairPath = parseTokenPath(tokenPath);
        _transferTokenIn(tokenPath, pairPath, amountIn);
        uint256 amountOut = _swapSupportingFeeOnTransferTokens(tokenPath, pairPath, to);
        require(amountOut >= amountOutMin, "SwapAggregator: INSUFFICIENT_OUTPUT_AMOUNT");
    }

    function swapTokenForExactToken(
        address[] calldata tokenPath,
        uint256 amountInMax,
        uint256 amountOut,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) {
        address[] memory pairPath = parseTokenPath(tokenPath);
        uint256 amountIn = _getAmountIn(tokenPath, pairPath, amountOut);
        require(amountIn <= amountInMax, "SwapAggregator: EXCESSIVE_INPUT_AMOUNT");
        _transferTokenIn(tokenPath, pairPath, amountIn);
        _swap(tokenPath, pairPath, amountIn, to);
    }

    function _transferTokenIn(address[] memory tokenPath, address[] memory pairPath, uint256 amountIn) private {
        if (tokenPath[0] == address(0)) {
            require(amountIn <= msg.value, "SwapAggregator: INVALID_TOKEN_INPUT_AMOUNT");
            IWETH(tokenPath[0]).deposit{ value: amountIn }();
            IWETH(tokenPath[0]).transfer(pairPath[0], amountIn);
        } else {
            IERC20(tokenPath[0]).transferFrom(msg.sender, pairPath[0], amountIn);
        }
    }

    function _swap(address[] memory tokenPath, address[] memory pairPath, uint256 amountIn, address to) private {
        uint256 amountOut;
        bool isEthOut = tokenPath[tokenPath.length - 1] == address(0);
        for (uint256 i = 0; i < tokenPath.length - 1; i++) {
            (address tokenIn, address tokenOut) = (tokenPath[i], tokenPath[i + 1]);
            amountOut = _getAmountOut(pairPath[i], tokenIn, tokenOut, amountIn);
            address recipient = i == tokenPath.length - 2 ? (isEthOut ? address(this) : to) : pairPath[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = tokenIn < tokenOut
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            ISwapPair(pairPath[i]).swap(amount0Out, amount1Out, recipient, new bytes(0));
            if (swapObserver != address(0) && (i == 0 || i == pairPath.length - 1)) {
                ISwapObserver(swapObserver).onSwap(pairPath[i], msg.sender, tokenIn, tokenOut, amountIn, amountOut);
            }
            amountIn = amountOut;
        }
        if (isEthOut) {
            IWETH(tokenPath[tokenPath.length - 1]).withdraw(amountOut);
            TransferHelper.safeTransferETH(to, amountOut);
        }

        if (address(this).balance > 0) {
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
        }
    }

    function _swapSupportingFeeOnTransferTokens(
        address[] memory tokenPath,
        address[] memory pairPath,
        address to
    ) private returns (uint256) {
        for (uint256 i = 0; i < tokenPath.length - 1; i++) {
            (address tokenIn, address tokenOut, address pair) = (tokenPath[i], tokenPath[i + 1], pairPath[i]);
            (uint256 reserve0, uint256 reserve1, ) = ISwapPair(pair).getReserves();
            uint256 amountIn = IERC20(tokenIn).balanceOf(pair) - (tokenIn < tokenOut ? reserve0 : reserve1);
            uint256 amountOut = _getAmountOut(pair, tokenIn, tokenOut, amountIn);
            address recipient = i == tokenPath.length - 2 ? address(this) : pairPath[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = tokenIn < tokenOut
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            ISwapPair(pair).swap(amount0Out, amount1Out, recipient, new bytes(0));
        }

        {
            address tokenOut = tokenPath[tokenPath.length - 1];
            uint256 amountOut = IERC20(tokenOut).balanceOf(address(this));
            if (tokenPath[tokenPath.length - 1] == address(0)) {
                IWETH(tokenOut).withdraw(amountOut);
                TransferHelper.safeTransferETH(to, amountOut);
            } else {
                TransferHelper.safeTransfer(tokenOut, to, amountOut);
            }

            if (address(this).balance > 0) {
                TransferHelper.safeTransferETH(msg.sender, address(this).balance);
            }
            return amountOut;
        }
    }

    function queryPairs() public view returns (address[] memory addresses) {
        addresses = new address[](_pairAddresses.length());
        for (uint256 i; i < _pairAddresses.length(); i++) {
            addresses[i] = _pairAddresses.at(i);
        }
    }

    function _getReserves(
        address pair,
        address token0,
        address token1
    ) private view returns (uint256 reserve0, uint256 reserve1) {
        (uint112 _reserve0, uint112 _reserve1, ) = ISwapPair(pair).getReserves();
        if (token0 == address(0)) token0 = WETH;
        if (token1 == address(0)) token1 = WETH;
        (reserve0, reserve1) = token0 < token1
            ? (uint256(_reserve0), uint256(_reserve1))
            : (uint256(_reserve1), uint256(_reserve0));
    }

    function _getAmountIn(
        address pair,
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) private view returns (uint256 amountIn) {
        (uint256 reserveIn, uint256 reserveOut) = _getReserves(pair, tokenIn, tokenOut);
        return SwapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function _getAmountIn(
        address[] memory tokenPath,
        address[] memory pairPath,
        uint256 amountOut
    ) public view returns (uint256 amountIn) {
        amountIn = amountOut;
        for (uint256 i = tokenPath.length - 1; i > 0; i--) {
            amountIn = _getAmountIn(pairPath[i - 1], tokenPath[i - 1], tokenPath[i], amountIn);
        }
    }

    function _getAmountOut(
        address pairAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private view returns (uint256 amountOut) {
        (uint256 reserveIn, uint256 reserveOut) = _getReserves(pairAddress, tokenIn, tokenOut);
        return SwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function _getAmountOut(
        address[] memory tokenPath,
        address[] memory pairPath,
        uint256 amountIn
    ) private view returns (uint256 amountOut) {
        amountOut = amountIn;
        for (uint256 i; i < tokenPath.length - 1; i++) {
            amountOut = _getAmountOut(pairPath[i], tokenPath[i], tokenPath[i + 1], amountOut);
        }
    }
}
