// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface ISyncswapPoolMaster {
    function pools(uint) external view returns (address);

    function poolsLength() external view returns (uint);
}
