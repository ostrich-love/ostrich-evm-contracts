// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IPool.sol";

interface IBOrichPool {
    struct PoolConfig {
        address rewardToken;
        uint256 depositStartTime;
        uint256 depositEndTime;
        uint256 claimStartTime;
        uint256 totalReward;
    }

    struct PoolInfo {
        PoolConfig config;
        address depositToken;
        uint256 depositAmount;
    }

    struct UserPoolInfo {
        address depositToken;
        uint256 depositAmount;
        uint256 claimTime;
    }

    function queryPoolInfo(address pool) external view returns (PoolInfo memory info);

    function queryAllPoolInfos() external view returns (PoolInfo[] memory infos);

    function queryUserPoolInfo(address pool, address user) external view returns (UserPoolInfo memory info);

    function queryAllUserPoolInfos(address user) external view returns (UserPoolInfo[] memory infos);

    function deposit(address token, uint256 amount) external payable;

    function withdraw(address depositToken, uint256 amount) external;

    function claim(address token) external;
}
