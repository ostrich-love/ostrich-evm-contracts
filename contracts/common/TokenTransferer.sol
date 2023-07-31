// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract TokenTransferer {
    function transferTokenTo(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            (bool success, ) = to.call{ value: amount }(new bytes(0));
            require(success, "TokenTransferer,ETH_TRANSFER_FAILED");
        } else {
            require(IERC20(token).balanceOf(address(this)) >= amount, "TokenTransferer,INSUFFICIENT_TOKEN_STOCK");
            IERC20(token).transfer(to, amount);
        }
    }

    function transferTokenFrom(address token, address from, uint256 amount) internal {
        if (token == address(0)) {
            require(msg.value >= amount, "INCORRECT_MSG_VALUE");
        } else {
            require(IERC20(token).balanceOf(from) >= amount, "TokenTransferer,INSUFFICIENT_TOKEN_BALANCE");
            require(
                IERC20(token).allowance(from, address(this)) >= amount,
                "TokenTransferer,INSUFFICIENT_TOKEN_ALLOWANCE"
            );
            IERC20(token).transferFrom(from, address(this), amount);
        }
    }

    function transferToken(address token, address from, address to, uint256 amount) internal {
        if (token == address(0)) {
            require(msg.value == amount, "INCORRECT_MSG_VALUE");
            if (to != address(this)) {
                (bool success, ) = to.call{ value: amount }(new bytes(0));
                require(success, "TokenTransferer,ETH_TRANSFER_FAILED");
            }
        } else if (from != to) {
            require(IERC20(token).balanceOf(from) >= amount, "TokenTransferer,INSUFFICIENT_TOKEN_BALANCE");
            require(
                IERC20(token).allowance(from, address(this)) >= amount,
                "TokenTransferer,INSUFFICIENT_TOKEN_ALLOWANCE"
            );
            IERC20(token).transferFrom(from, to, amount);
        }
    }
}
