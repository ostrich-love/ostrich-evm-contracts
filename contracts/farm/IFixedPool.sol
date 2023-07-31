// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IPool.sol";

interface IFixedPool is IPool {
    event DepositEvent(
        address user,
        uint256 depositId,
        uint256 amount,
        uint256 lockUnits,
        uint256 depositWeight,
        uint256 timestamp
    );

    event WithdrawEvent(address user, uint256 depositId, uint256 amount, uint256 timestamp);
    event HarvestEvent(address user, uint256 amount, uint256 timestamp);

    struct Deposition {
        uint256 depositId;
        uint256 amount;
        uint256 rewardIndex;
        uint256 reward;
        uint256 depositTime;
        uint256 lockUnits;
        uint256 weight;
        uint256 extraWeight;
    }

    function queryAccelerateConfig() external view returns (address accelerateNFT, uint256 accelerateRate);

    function queryUserAccelerateNFT(address user) external view returns (address nft, uint256 tokenId);

    function queryUserDepositions(address user) external view returns (Deposition[] memory depositions);

    function queryPool()
        external
        view
        returns (
            address depositToken,
            address rewardToken,
            uint256 startTime,
            uint256 endTime,
            uint256 weeklyReward,
            uint256 lockUnitSpan,
            uint256 rewardIndex,
            uint256 lastDistributeTime,
            uint256 totalDeposits,
            uint256 totalWeight,
            uint256 nextDepositId,
            address depositVault,
            address rewardVault
        );

    function depositAccelerateNFT(uint256 tokenId) external;

    function withdrawAccelerateNFT(uint256 tokenId) external;

    function deposit(uint256 amount, uint256 lockUnits) external payable;

    function harvest(uint256 depositId) external;

    function withdraw(uint256 depositId) external;
}
