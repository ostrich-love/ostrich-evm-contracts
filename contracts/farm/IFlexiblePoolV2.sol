// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IPool.sol";

interface IFlexiblePoolV2 is IPool {
    event DepositEvent(address user, uint256 amount, uint256 timestamp);
    event WithdrawEvent(address user, uint256 amount, uint256 timestamp);
    event HarvestEvent(address user, uint256 amount, uint256 timestamp);

    struct Deposition {
        uint256 amount;
        uint256 weight;
        uint256 rewardIndex;
        uint256 reward;
        uint256 lastHarvestTime;
        uint256 extraWeight;
    }

    function queryPool()
        external
        view
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256 rewardIndex,
            uint256 totalDeposits,
            uint256 totalWeight,
            uint256 pointExchangeRate,
            address depositToken,
            address rewardToken,
            address rewardUnlocker,
            address depositVault
        );

    function queryAccelerateConfig() external view returns (address accelerateNFT, uint256 accelerateRate);

    function queryUserAccelerateNFT(address user) external view returns (address nft, uint256 tokenId);

    function depositAccelerateNFT(uint256 tokenId) external;

    function withdrawAccelerateNFT(uint256 tokenId) external;

    function queryUserPoints(address user) external view returns (uint256);

    function queryUserDeposition(address user) external view returns (Deposition memory deposition);

    function deposit(uint256 amount) external payable;

    function withdraw(uint256 amount) external;

    function harvest() external;
}
