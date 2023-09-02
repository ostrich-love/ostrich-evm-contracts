// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../common/TokenTransferer.sol";
import "../farm/IRewardUnlocker.sol";
import "./ISwapObserver.sol";
import "./ITradingPoolV2.sol";
import "../vault/IDepositVault.sol";

contract TradingPoolV2 is
    OwnableUpgradeable,
    ISwapObserver,
    ITradingPoolV2,
    TokenTransferer,
    ReentrancyGuardUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    uint256 constant INDEX_PRECISION = 1e12;
    address[] private _callers;
    address private _rewardToken;
    address private _rewardUnlocker;
    uint256 private _pointExchangeRate;
    EnumerableSet.AddressSet private _pools;
    mapping(address => PoolInfo) private _poolInfos;
    mapping(address => mapping(address => UserPoolInfo)) private _userPoolInfos;

    address private _depositVault;
    uint256 private _cumulativeDistributes;

    function initialize(
        address rewardToken,
        address depositVault,
        address rewardUnlocker,
        uint256 pointExchangeRate
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        _rewardToken = rewardToken;
        _depositVault = depositVault;
        _rewardUnlocker = rewardUnlocker;
        _pointExchangeRate = pointExchangeRate;
    }

    function updateDepositVault(address val) public onlyOwner {
        _depositVault = val;
    }

    function queryDepositVault() public view returns (address) {
        return _depositVault;
    }

    function queryCallers() public view returns (address[] memory) {
        return _callers;
    }

    function updateCallers(address[] memory v) public onlyOwner {
        _callers = v;
    }

    function updatePointExchangeRate(uint256 val) public onlyOwner {
        _pointExchangeRate = val;
    }

    function setPool(address pool, PoolConfig memory config) public onlyOwner {
        _poolInfos[pool].config = config;
        _pools.add(pool);
    }

    function removePools(address[] memory pools) public onlyOwner {
        for (uint256 i = 0; i < pools.length; i++) {
            delete _poolInfos[pools[i]];
            _pools.remove(pools[i]);
        }
    }

    function queryPoolView(address pool) public view override returns (PoolView memory v) {
        v.pool = pool;
        v.info = _poolInfos[pool];
    }

    function queryAllPoolViews() public view override returns (PoolView[] memory pools) {
        pools = new PoolView[](_pools.length());
        for (uint256 i; i < pools.length; i++) {
            pools[i] = queryPoolView(_pools.at(i));
        }
    }

    function queryUserPoolView(address pool, address user) public view override returns (UserPoolView memory v) {
        UserPoolInfo memory info = _userPoolInfos[pool][user];
        info.pendingReward += _queryPendingReward(pool, user);
        return UserPoolView({ pool: pool, info: info });
    }

    function queryAllUserPoolViews(address user) external view override returns (UserPoolView[] memory views) {
        views = new UserPoolView[](_pools.length());
        for (uint256 i; i < views.length; i++) {
            views[i] = queryUserPoolView(_pools.at(i), user);
        }
    }

    function queryRewardToken() external view override returns (address) {
        return _rewardToken;
    }

    function onSwap(
        address pool,
        address trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) external override {
        PoolInfo memory poolInfo = _poolInfos[pool];
        uint256 timestamp = block.timestamp;
        if (poolInfo.config.startTime > timestamp || poolInfo.config.endTime < timestamp) return;
        uint256 points;
        uint256 amount;
        if (tokenIn == poolInfo.config.targetToken) {
            points = (amountIn * poolInfo.config.amountInRate) / 1e18;
            amount = amountIn;
        } else if (tokenOut == poolInfo.config.targetToken) {
            points = (amountOut * poolInfo.config.amountOutRate) / 1e18;
            amount = amountOut;
        }
        if (points == 0) return;
        _distribute(pool);
        _poolInfos[pool].points += points;
        _poolInfos[pool].cumulativePoints += points;
        _poolInfos[pool].cumulativeAmount += amount;
        _poolInfos[pool].amount += amount;
        _userPoolInfos[pool][trader].points += points;
        _userPoolInfos[pool][trader].cumulativePoints += points;
        _userPoolInfos[pool][trader].cumulativeAmount += amount;
        _userPoolInfos[pool][trader].amount += amount;
        if (_userPoolInfos[pool][trader].rewardIndex == 0) {
            _userPoolInfos[pool][trader].rewardIndex = _poolInfos[pool].rewardIndex;
        }
        emit SwapEvent(pool, trader, tokenIn, tokenOut, amountIn, amountOut, points, timestamp);
    }

    function _queryPendingPoolReward(
        address pool
    ) private view returns (uint256 vaultCumulativeDeposits, uint256 pendingRewardIndex, uint256 reward) {
        if (_poolInfos[pool].points > 0) {
            vaultCumulativeDeposits = IDepositVault(_depositVault).cumulativeDepositsOf(_rewardToken, address(this));
            reward = vaultCumulativeDeposits - _cumulativeDistributes;
            if (reward > 0) {
                pendingRewardIndex = (reward * INDEX_PRECISION) / _poolInfos[pool].points;
            }
        }
    }

    function _distribute(address pool) public {
        (uint256 vaultCumulativeDeposits, uint256 rewardIndex, uint256 reward) = _queryPendingPoolReward(pool);
        if (vaultCumulativeDeposits > 0 && rewardIndex > 0 && reward > 0) {
            _poolInfos[pool].cumulativeRewards += reward;
            _poolInfos[pool].rewardIndex += rewardIndex;
            _poolInfos[pool].lastDistributeTime = block.timestamp;
            _cumulativeDistributes = vaultCumulativeDeposits;
        }
    }

    function claimAll() external override nonReentrant {
        uint256 amount;
        address user = msg.sender;
        for (uint256 i = _pools.length(); i > 0; i--) {
            amount += _claim(_pools.at(i - 1), user);
        }
        require(amount > 0, "NOTHING_TO_CLAIM");
        IDepositVault(_depositVault).withdraw(_rewardToken, user, amount);
    }

    function claim(address pool) external override nonReentrant {
        uint256 amount = _claim(pool, msg.sender);
        require(amount > 0, "NOTHING_TO_CLAIM");
        IDepositVault(_depositVault).withdraw(_rewardToken, msg.sender, amount);
    }

    function _adjustRewardByStakingPoint(address trader, uint256 rewardAmount) private returns (uint256) {
        if (_pointExchangeRate > 0) {
            uint256 stakePoints = queryUserStakePoints(trader);
            if (stakePoints == 0) return 0;
            uint256 equivalentReward = (stakePoints * 100) / _pointExchangeRate;
            if (equivalentReward >= rewardAmount) {
                _reducePoints(trader, (rewardAmount * _pointExchangeRate) / 100);
            } else {
                _reducePoints(trader, stakePoints);
                rewardAmount = equivalentReward;
            }
        }
        return rewardAmount;
    }

    function _claim(address pool, address trader) private returns (uint256 rewardAmount) {
        _distribute(pool);
        uint256 timestamp = block.timestamp;
        if (_userPoolInfos[pool][trader].points == 0) return 0;
        if (timestamp - _userPoolInfos[pool][trader].lastClaimTime < _poolInfos[pool].config.claimInterval) return 0;
        _updateReward(pool, trader);
        rewardAmount = _adjustRewardByStakingPoint(trader, _userPoolInfos[pool][trader].pendingReward);
        if (rewardAmount == 0) return 0;
        _poolInfos[pool].points -= _userPoolInfos[pool][trader].points;
        _poolInfos[pool].amount -= _userPoolInfos[pool][trader].amount;
        _userPoolInfos[pool][trader].pendingReward -= rewardAmount;
        _userPoolInfos[pool][trader].points = 0;
        _userPoolInfos[pool][trader].amount = 0;
        _userPoolInfos[pool][trader].lastClaimTime = timestamp;
        _userPoolInfos[pool][trader].claimedReward += rewardAmount;
        emit ClaimEvent(pool, trader, rewardAmount, timestamp);
    }

    function _queryPendingReward(address pool, address trader) public view returns (uint256 pendingReward) {
        uint256 points = _userPoolInfos[pool][trader].points;
        if (points > 0) {
            (, uint256 pendingRewardIndex, ) = _queryPendingPoolReward(pool);
            uint256 rewardIndex = _poolInfos[pool].rewardIndex + pendingRewardIndex;
            pendingReward = (points * (rewardIndex - _userPoolInfos[pool][trader].rewardIndex)) / INDEX_PRECISION;
        }
    }

    function _updateReward(address pool, address trader) private {
        if (_userPoolInfos[pool][trader].rewardIndex > 0) {
            uint256 reward = _queryPendingReward(pool, trader);
            if (reward > 0) {
                _userPoolInfos[pool][trader].pendingReward += reward;
            }
        }
        _userPoolInfos[pool][trader].rewardIndex = _poolInfos[pool].rewardIndex;
    }

    function emergencyWithdraw(address token, address to, uint256 amount) public onlyOwner {
        transferTokenTo(token, to, amount);
    }

    function queryUserStakePoints(address user) public view override returns (uint256) {
        return IRewardUnlocker(_rewardUnlocker).queryPoints(user);
    }

    function _reducePoints(address user, uint256 points) private {
        IRewardUnlocker(_rewardUnlocker).reducePoints(user, points);
    }
}
