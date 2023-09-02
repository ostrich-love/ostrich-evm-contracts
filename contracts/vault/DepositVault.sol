// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


import "./IDepositVault.sol";


contract DepositVault is OwnableUpgradeable, ReentrancyGuardUpgradeable, IDepositVault {

    mapping(address => mapping(address => uint)) public override balanceOf;

    mapping(address => uint) public reserves;

    mapping(address => mapping(address => uint)) public override cumulativeDepositsOf;

    receive() external payable {
        _deposit(address(0), msg.sender, msg.value);
    }

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function depositETH(address account) public payable override nonReentrant {
        _deposit(address(0), account, msg.value);
    }

    function deposit(address token, address account) public payable override nonReentrant {
        uint256 amount = token == address(0) ? msg.value : (IERC20(token).balanceOf(address(this)) - reserves[token]);
        _deposit(token, account, amount);
    }

    function batchDeposit(
        address token,
        address[] memory accounts,
        uint256[] memory weights
    ) public payable override nonReentrant {
        require(accounts.length > 0 && accounts.length == weights.length, "DepositVault,Invalid parameters");
        uint256 amount = token == address(0) ? msg.value : (IERC20(token).balanceOf(address(this)) - reserves[token]);
        uint256 totalWeight;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i];
        }
        for (uint256 i = 0; i < accounts.length; i++) {
            _deposit(token, accounts[i], (amount * weights[i]) / totalWeight);
        }
    }

    function withdraw(address token, address to, uint256 amount) public override nonReentrant {
        address account = msg.sender;
        require(balanceOf[token][account] >= amount, "OstrichVault,INSUFFICIENT_BALACNE");
        require(reserves[token] >= amount, "OstrichVault,INSUFFICIENT_RESERVE");
        _transferTokenTo(token, to, amount);
        _withdraw(token, account, amount);
    }

    function emergencyWithdraw(address token, address to, uint256 amount) public onlyOwner {
        _transferTokenTo(token, to, amount);
    }

    function _withdraw(address token, address account, uint256 amount) private {
        balanceOf[token][account] -= amount;
        reserves[token] -= amount;
    }

    function _deposit(address token, address account, uint256 amount) private {
        balanceOf[token][account] += amount;
        cumulativeDepositsOf[token][account] += amount;
        reserves[token] += amount;
    }

    function _transferTokenTo(address token, address to, uint256 amount) private {
        if (to == address(this)) return;
        if (token == address(0)) {
            (bool success, ) = to.call{ value: amount }(new bytes(0));
            require(success, "TokenTransferer,ETH_TRANSFER_FAILED");
        } else {
            require(IERC20(token).balanceOf(address(this)) >= amount, "OstrichVault,INSUFFICIENT_TOKEN_STOCK");
            IERC20(token).transfer(to, amount);
        }
    }
}
