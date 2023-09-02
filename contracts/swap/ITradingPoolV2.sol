// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ITradingPoolV2 {
    event SwapEvent(
        address pool,
        address trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 points,
        uint256 timestamp
    );
    event ClaimEvent(address pool, address trader, uint256 amount, uint256 timestamp);

    struct PoolConfig {
        address targetToken;
        uint256 startTime;
        uint256 endTime;
        uint256 amountInRate;
        uint256 amountOutRate;
        uint256 claimInterval;
    }

    struct PoolInfo {
        PoolConfig config;
        uint256 rewardIndex;
        uint256 lastDistributeTime;
        uint256 points;
        uint256 amount;
        uint256 cumulativePoints;
        uint256 cumulativeAmount;
        uint256 cumulativeRewards;
    }

    struct PoolView {
        address pool;
        PoolInfo info;
    }

    struct UserPoolInfo {
        address pool;
        uint256 points;
        uint256 amount;
        uint256 cumulativePoints;
        uint256 cumulativeAmount;
        uint256 rewardIndex;
        uint256 pendingReward;
        uint256 lastClaimTime;
        uint256 claimedReward;
    }

    struct UserPoolView {
        address pool;
        UserPoolInfo info;
    }

    function queryRewardToken() external view returns (address);

    function queryPoolView(address pool) external view returns (PoolView memory);

    function queryAllPoolViews() external view returns (PoolView[] memory views);

    function queryUserPoolView(address pool, address user) external view returns (UserPoolView memory v);

    function queryAllUserPoolViews(address user) external view returns (UserPoolView[] memory views);

    function queryUserStakePoints(address user) external view returns (uint256);

    function claim(address pool) external;

    function claimAll() external;
}
