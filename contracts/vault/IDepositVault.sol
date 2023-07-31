// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IDepositVault {
    function balanceOf(address token, address account) external view returns (uint balance);

    function depositETH(address account) external payable;

    function deposit(address token, address account) external payable;

    function withdraw(address token, address to, uint256 amount) external;
}
