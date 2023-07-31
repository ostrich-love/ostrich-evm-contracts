// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../common/TokenTransferer.sol";
import "../IPoolWrapper.sol";
import "./ISyncswapPool.sol";
import "./ISyncswapVault.sol";

contract SyncswapPoolWrapper is IPoolWrapper, OwnableUpgradeable, TokenTransferer {
    function initialize() public initializer {
        __Ownable_init();
    }

    function getPoolVault(address pool) public view override returns (address) {
        return ISyncswapPool(pool).vault();
    }

    function swap(address pool, bytes calldata data_) external override returns (uint256 amountOut) {
        (address tokenIn, uint256 amountIn, address to, uint8 withdrawMode) = abi.decode(
            data_,
            (address, uint256, address, uint8)
        );
        bytes memory data = abi.encode(tokenIn, to, withdrawMode);
        ISyncswapPool p = ISyncswapPool(pool);
        address vault = p.vault();
        ISyncswapVault(vault).deposit(tokenIn, pool);
        require(ISyncswapVault(vault).balanceOf(tokenIn, pool) >= amountIn, "ISyncswapVault(vault).deposit failed");
        ISyncswapPool.TokenAmount memory tokenAmount = p.swap(data, to, address(0), "");
        return tokenAmount.amount;
    }

    function getAmountOut(
        address pool,
        address tokenIn,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        return ISyncswapPool(pool).getAmountOut(tokenIn, amountIn, address(0));
    }

    function getAmountIn(
        address pool,
        address tokenOut,
        uint256 amountOut
    ) external view override returns (uint256 amountIn) {
        return ISyncswapPool(pool).getAmountIn(tokenOut, amountOut, address(0));
    }

    function token0(address pool) external view override returns (address) {
        return ISyncswapPool(pool).token0();
    }

    function token1(address pool) external view override returns (address) {
        return ISyncswapPool(pool).token1();
    }

    function getReserves(address pool) external view override returns (uint, uint) {
        return ISyncswapPool(pool).getReserves();
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "SyncswapPoolWrapper: TRANSFER_FAILED");
    }
}
