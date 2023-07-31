// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IRewardVault {
    function transferTo(address token, address to, uint256 amount) external;
}
