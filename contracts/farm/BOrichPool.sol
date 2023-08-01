// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../common/TokenTransferer.sol";
import "./IBOrichPool.sol";

contract BOrichPool is OwnableUpgradeable, TokenTransferer, ReentrancyGuardUpgradeable, IBOrichPool {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => mapping(address => UserPoolInfo)) _userPoolInfos;
    mapping(address => PoolInfo) _poolInfos;

    EnumerableSet.AddressSet private _pools;

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function setPool(address depositToken, PoolConfig memory v) public onlyOwner {
        _poolInfos[depositToken].config = v;
        _poolInfos[depositToken].depositToken = depositToken;
        _pools.add(depositToken);
    }

    function queryPoolInfo(address depositToken) public view override returns (PoolInfo memory info) {
        return _poolInfos[depositToken];
    }

    function queryAllPoolInfos() external view override returns (PoolInfo[] memory infos) {
        infos = new PoolInfo[](_pools.length());
        for (uint256 i; i < infos.length; i++) {
            infos[i] = queryPoolInfo(_pools.at(i));
        }
    }

    function queryUserPoolInfo(
        address depositToken,
        address user
    ) public view override returns (UserPoolInfo memory info) {
        return _userPoolInfos[depositToken][user];
    }

    function queryAllUserPoolInfos(address user) external view override returns (UserPoolInfo[] memory infos) {
        infos = new UserPoolInfo[](_pools.length());
        for (uint256 i; i < infos.length; i++) {
            infos[i] = queryUserPoolInfo(_pools.at(i), user);
        }
    }

    function deposit(address depositToken, uint256 amount) external payable override nonReentrant {
        address user = msg.sender;
        uint256 timestamp = block.timestamp;
        require(timestamp >= _poolInfos[depositToken].config.depositStartTime, "ERR_POOL_DEPOSIT_NOT_STARTED");
        require(timestamp <= _poolInfos[depositToken].config.depositEndTime, "ERR_POOL_DEPOSIT_ENDED");
        _poolInfos[depositToken].depositAmount += amount;
        _userPoolInfos[depositToken][user].depositAmount += amount;
        transferTokenFrom(depositToken, user, amount);
    }

    function withdraw(address depositToken, uint256 amount) external override nonReentrant {
        address user = msg.sender;
        require(_userPoolInfos[depositToken][user].depositAmount >= amount, "ERR_EXCEED_MAX_AMOUNT");
        _poolInfos[depositToken].depositAmount -= amount;
        _userPoolInfos[depositToken][user].depositAmount -= amount;
        transferTokenTo(depositToken, user, amount);
    }

    function claim(address depositToken) external override nonReentrant {
        address user = msg.sender;
        uint256 timestamp = block.timestamp;
        require(timestamp >= _poolInfos[depositToken].config.claimStartTime, "ERR_CLAIM_NOT_STARTED");
        uint256 depositAmount = _userPoolInfos[depositToken][user].depositAmount;
        require(depositAmount > 0, "ERR_NO_DEPOSIT_FOUND");
        require(_userPoolInfos[depositToken][user].claimTime == 0, "ERR_DUPLICATE_CLAIM");
        uint256 reward = (_poolInfos[depositToken].config.totalReward * depositAmount) /
            _poolInfos[depositToken].depositAmount;
        require(reward > 0, "ERR_ZERO_REWARD");
        _userPoolInfos[depositToken][user].claimTime = timestamp;
        transferTokenTo(depositToken, user, depositAmount);
        transferTokenTo(_poolInfos[depositToken].config.rewardToken, user, reward);
    }

    function emergencyWithdraw(address token, address to, uint256 amount) public onlyOwner {
        transferTokenTo(token, to, amount);
    }
}
