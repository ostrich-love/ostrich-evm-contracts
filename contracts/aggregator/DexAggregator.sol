// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./IPoolWrapper.sol";
import "./IDexAggregator.sol";
import "../common/IWETH.sol";
import "../swap/ISwapObserver.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);

    function transferFrom(address from, address to, uint256 amount) external payable;
}

contract DexAggregator is IDexAggregator, OwnableUpgradeable {
    address public WETH;
    address[] private _poolWrappers;
    address public swapObserver;

    fallback() external payable {}

    receive() external payable {}

    function initialize(address weth_, address swapObserver_) public initializer {
        __Ownable_init();
        WETH = weth_;
        swapObserver = swapObserver_;
    }

    function updateSwapObserver(address val) public onlyOwner {
        swapObserver = val;
    }

    function updateWETH(address weth) public onlyOwner {
        WETH = weth;
    }

    function updatePoolWrappers(address[] memory wrappers) public onlyOwner {
        _poolWrappers = wrappers;
    }

    function queryPoolWrappers() public view returns (address[] memory) {
        return _poolWrappers;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "SwapAggregator: EXPIRED");
        _;
    }

    function getAmountOut(
        Pool[] memory pools,
        address tokenIn,
        uint256 amountIn
    ) public view override returns (address tokenOut, uint256 amountOut) {
        for (uint256 i; i < pools.length; i++) {
            Pool memory p = pools[i];
            IPoolWrapper wrapper = getWrapper(p.t);
            address token0 = wrapper.token0(p.a);
            if (tokenIn == address(0)) tokenIn = WETH;
            tokenOut = tokenIn == token0 ? wrapper.token1(p.a) : token0;
            amountOut = wrapper.getAmountOut(p.a, tokenIn, amountIn);
            if (i < pools.length - 1) {
                amountIn = amountOut;
                tokenIn = tokenOut;
            } else {
                if (tokenOut == WETH) tokenOut = address(0);
            }
        }
    }

    function swap(
        Pool[] memory pools,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) {
        for (uint256 i; i < pools.length; i++) {
            Pool memory p = pools[i];
            IPoolWrapper wrapper = getWrapper(p.t);
            if (i == 0) _transferFrom(tokenIn, wrapper.getPoolVault(p.a), amountIn, p.t);
            if (tokenIn == address(0)) tokenIn = WETH;
            address tokenOut = tokenIn == wrapper.token0(p.a) ? wrapper.token1(p.a) : wrapper.token0(p.a);
            uint256 amountOut = i == pools.length - 1
                ? _swapLast(p, tokenIn, tokenOut, amountIn, to)
                : _swapInter(p, pools[i + 1], tokenIn, amountIn);

            if (swapObserver != address(0) && (i == 0 || i == pools.length - 1)) {
                ISwapObserver(swapObserver).onSwap(p.a, msg.sender, tokenIn, tokenOut, amountIn, amountOut);
            }
            if (i == pools.length - 1) {
                _hanldeOut(amountOut, amountOutMin, to);
            } else {
                amountIn = amountOut;
                tokenIn = tokenOut;
            }
        }
    }

    function _getPoolVault(Pool memory p) private view returns (address) {
        return getWrapper(p.t).getPoolVault(p.a);
    }

    function _swapInter(
        Pool memory p,
        Pool memory nextp,
        address tokenIn,
        uint256 amountIn
    ) private returns (uint256 amountOut) {
        address vault = _getPoolVault(nextp);
        if (p.t == POOL_TYPE_UNISWAP) {
            return getWrapper(p.t).swap(p.a, abi.encode(tokenIn, amountIn, vault));
        }
        if (p.t == POOL_TYPE_SYNCSWAP) {
            uint8 withdrawMode = 2;
            return getWrapper(p.t).swap(p.a, abi.encode(tokenIn, amountIn, vault, withdrawMode));
        }
    }

    function _swapLast(
        Pool memory p,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address to
    ) private returns (uint256 amountOut) {
        if (p.t == POOL_TYPE_UNISWAP) {
            address recipient = tokenOut == WETH ? address(this) : to;
            amountOut = getWrapper(p.t).swap(p.a, abi.encode(tokenIn, amountIn, recipient));
        }
        if (p.t == POOL_TYPE_SYNCSWAP) {
            uint8 withdrawMode = 1;
            amountOut = getWrapper(p.t).swap(p.a, abi.encode(tokenIn, amountIn, to, withdrawMode));
        }
    }

    function _hanldeOut(uint256 amountOut, uint256 amountOutMin, address to) private {
        require(amountOut >= amountOutMin, "DexAggregator,INSUFFICIENT_AMOUNT_OUT");
        if (IERC20(WETH).balanceOf(address(this)) >= amountOut) {
            IWETH(WETH).withdraw(amountOut);
            _transferETH(to, amountOut);
        }
    }

    function _transferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{ value: value }(new bytes(0));
        require(success, "DexAggregator: ETH_TRANSFER_FAILED");
    }

    function getWrapper(uint8 poolType) public view override returns (IPoolWrapper) {
        require(poolType < _poolWrappers.length, "INVLAID_POOL_TYPE");
        return IPoolWrapper(_poolWrappers[poolType]);
    }

    function _transferFrom(address token, address to, uint256 amount, uint8 poolType) private {
        if (token != address(0)) {
            IERC20(token).transferFrom(msg.sender, to, amount);
            return;
        }
        require(amount <= msg.value, "DexAggregator: INVALID_TOKEN_INPUT_AMOUNT");
        if (poolType == POOL_TYPE_SYNCSWAP) {
            _transferETH(to, amount);
        } else {
            IWETH(WETH).deposit{ value: amount }();
            IWETH(WETH).transfer(to, amount);
        }
    }
}
