// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IERC1155Burnable {
    function burn(uint256 id, uint256 amount) external;
}
