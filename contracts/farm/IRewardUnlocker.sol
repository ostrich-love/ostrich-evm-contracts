// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IRewardUnlocker {
    event DepositEvent(address user, address depositToken, uint256 amount, uint256 timestamp);
    event WithdrawEvent(address user, address depositToken, uint256 amount, uint256 timestamp);

    struct Pool {
        address depositToken;
        uint256 unlockSpeed;
        uint256 totalDeposits;
        bool enabled;
    }

    struct UserStore {
        mapping(address => uint256) deposits;
        uint256 lastCalculateBlock;
        uint256 points;
    }

    struct DepositView {
        address token;
        uint256 amount;
    }

    struct UserView {
        address user;
        DepositView[] deposits;
        uint256 points;
        uint256 pendingPoints;
        uint256 lastCalculateBlock;
    }

    function queryUserView(address user) external view returns (UserView memory);

    function deposit(address token, uint256 amount) external;

    function withdraw(address token, uint256 amount) external;

    function reducePoints(address user, uint256 amount) external;

    function queryPoints(address user) external view returns (uint256);

    function queryPools() external view returns (Pool[] memory pools);

    function queryUserDepositions(
        address user
    ) external view returns (address[] memory tokens, uint256[] memory amounts);
}
