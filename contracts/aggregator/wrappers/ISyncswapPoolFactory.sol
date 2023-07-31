// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface ISyncswapPoolFactory {
    event PoolCreated(address indexed token0, address indexed token1, address pool);

    function getPool(address tokenA, address tokenB) external view returns (address pool);
}
