// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IRewardVault.sol";

contract RewardVault is OwnableUpgradeable, ReentrancyGuardUpgradeable, IRewardVault {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _callers;

    modifier onlyCaller() {
        require(isCaller(msg.sender), "Caller:NOT_MINTER");
        _;
    }

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function addCallers(address[] memory accounts) public onlyOwner {
        for (uint256 i; i < accounts.length; i++) {
            _callers.add(accounts[i]);
        }
    }

    function removeCallers(address[] memory accounts) public onlyOwner {
        for (uint256 i; i < accounts.length; i++) {
            _callers.remove(accounts[i]);
        }
    }

    function getCallers() public view returns (address[] memory accounts) {
        accounts = new address[](_callers.length());
        for (uint256 i; i < accounts.length; i++) {
            accounts[i] = _callers.at(i);
        }
    }

    function isCaller(address account) public view returns (bool) {
        return _callers.contains(account);
    }

    function transferTo(address token, address to, uint256 amount) public override onlyCaller nonReentrant {
        require(IERC20(token).balanceOf(address(this)) >= amount, "RewardVault,INSUFFICIENT_TOKEN_STOCK");
        IERC20(token).transfer(to, amount);
    }
}
