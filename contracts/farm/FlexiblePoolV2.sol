// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../common/TokenTransferer.sol";
import "../common/ERC721Transferer.sol";
import "./IFlexiblePoolV2.sol";
import "./IRewardUnlocker.sol";
import "../vault/IDepositVault.sol";

contract FlexiblePoolV2 is
    OwnableUpgradeable,
    TokenTransferer,
    ReentrancyGuardUpgradeable,
    ERC721Transferer,
    IFlexiblePoolV2
{
    uint256 constant INDEX_PRECISION = 1e12;

    address private _depositToken;
    address private _rewardToken;
    address private _rewardUnlocker;

    uint256 private _startTime;
    uint256 private _endTime;
    uint256 private _rewardIndex;
    uint256 private _totalDeposits;
    uint256 private _totalWeight;
    uint256 private _pointExchangeRate;

    mapping(address => Deposition) _depositions;

    address private _accelerateNFT;
    uint256 private _accelerateRate;
    mapping(address => uint256) private _userAccelerateNFTs;
    address private _depositVault;
    uint256 private _cumulativeDistributes;

    function initialize(
        address depositToken,
        address rewardToken,
        address rewardUnlocker,
        address depositVault
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        _depositToken = depositToken;
        _rewardToken = rewardToken;
        _rewardUnlocker = rewardUnlocker;
        _depositVault = depositVault;
    }

    function updateDepositVault(address val) public onlyOwner {
        _depositVault = val;
    }

    function updateAccelerateConfig(address accelerateNFT, uint256 accelerateRate) public onlyOwner {
        _accelerateNFT = accelerateNFT;
        _accelerateRate = accelerateRate;
    }

    function queryAccelerateConfig() public view override returns (address accelerateNFT, uint256 accelerateRate) {
        accelerateNFT = _accelerateNFT;
        accelerateRate = _accelerateRate;
    }

    function queryUserAccelerateNFT(address user) public view override returns (address nft, uint256 tokenId) {
        nft = _accelerateNFT;
        tokenId = _userAccelerateNFTs[user];
    }

    function depositAccelerateNFT(uint256 tokenId) public override nonReentrant {
        address user = msg.sender;
        distribute();
        updateReward(user);
        require(_accelerateNFT != address(0), "ACCELERATE_NOT_SUPPORTED");
        require(_userAccelerateNFTs[user] == 0, "DUPLICATE_DEPOSIT_ACCELERATE_NFT");
        _userAccelerateNFTs[user] = tokenId;
        transferERC721From(_accelerateNFT, user, tokenId);
        uint256 weight = _depositions[user].weight;
        if (weight > 0) {
            uint256 extraWeight = (weight * _accelerateRate) / 100;
            _totalWeight += extraWeight;
            _depositions[user].extraWeight = extraWeight;
        }
    }

    function withdrawAccelerateNFT(uint256 tokenId) public override nonReentrant {
        address user = msg.sender;
        distribute();
        updateReward(user);
        require(_accelerateNFT != address(0), "ACCELERATE_NOT_SUPPORTED");
        require(_userAccelerateNFTs[user] == tokenId, "NO_ACCELERATE_NFT_DEPOSITED");
        _userAccelerateNFTs[user] = 0;
        transferERC721To(_accelerateNFT, user, tokenId);
        uint256 extraWeight = _depositions[user].extraWeight;
        if (extraWeight > 0) {
            _totalWeight -= extraWeight;
            _depositions[user].extraWeight = 0;
        }
    }

    function updateStartTime(uint256 val) public onlyOwner {
        _startTime = val;
    }

    function updateEndTime(uint256 val) public onlyOwner {
        _endTime = val;
    }

    function updatePointExchangeRate(uint256 val) public onlyOwner {
        _pointExchangeRate = val;
    }

    function queryUserDeposition(address user) public view override returns (Deposition memory deposition) {
        deposition = _depositions[user];
        deposition.reward += queryPendingReward(user);
        return deposition;
    }

    function queryPool()
        public
        view
        override
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
        )
    {
        startTime = _startTime;
        endTime = _endTime;
        rewardIndex = _rewardIndex;
        totalDeposits = _totalDeposits;
        pointExchangeRate = _pointExchangeRate;
        depositToken = _depositToken;
        rewardToken = _rewardToken;
        rewardUnlocker = _rewardUnlocker;
        totalWeight = _totalWeight;
        depositVault = _depositVault;
    }

    function deposit(uint256 amount) public payable override nonReentrant {
        uint256 timestamp = block.timestamp;
        require(timestamp >= _startTime, "ERR_POOL_NOT_STARTED");
        require(timestamp <= _endTime, "ERR_POOL_ENDED");
        distribute();
        address user = msg.sender;
        uint256 weight = amount;
        uint256 extraWeight;
        if (_userAccelerateNFTs[user] != 0) {
            extraWeight = (amount * _accelerateRate) / 100;
        }
        if (_depositions[user].amount > 0) {
            updateReward(user);
            _depositions[user].amount += amount;
            _depositions[user].weight += weight;
            _depositions[user].extraWeight += extraWeight;
        } else {
            _depositions[user] = Deposition({
                amount: amount,
                weight: weight,
                rewardIndex: _rewardIndex,
                reward: 0,
                lastHarvestTime: timestamp,
                extraWeight: extraWeight
            });
        }
        _totalDeposits += amount;
        _totalWeight += (weight + extraWeight);
        transferToken(_depositToken, user, _depositVault, amount);
        IDepositVault(_depositVault).deposit(_depositToken, address(this));
        emit DepositEvent(user, amount, timestamp);
        emit TotalDepositsChanged(_depositToken, _totalDeposits, timestamp);
    }

    function withdraw(uint256 amount) public override nonReentrant {
        _withdraw(msg.sender, amount);
    }

    function _withdraw(address user, uint256 amount) private {
        distribute();
        updateReward(user);
        require(amount > 0, "ZERO_AMOUNT");
        require(_depositions[user].amount >= amount, "ERR_INSUFFICIENT_AMOUNT");
        uint256 extraWeight;
        if (_depositions[user].extraWeight > 0) {
            extraWeight = (_depositions[user].extraWeight * amount) / _depositions[user].amount;
            if (extraWeight > _depositions[user].extraWeight) {
                extraWeight = _depositions[user].extraWeight;
            }
        }
        _totalDeposits -= amount;
        _totalWeight -= (amount + extraWeight);
        _depositions[user].amount -= amount;
        _depositions[user].weight -= amount;
        _depositions[user].extraWeight -= extraWeight;
        IDepositVault(_depositVault).withdraw(_depositToken, user, amount);
        emit WithdrawEvent(user, amount, block.timestamp);
        emit TotalDepositsChanged(_depositToken, _totalDeposits, block.timestamp);
    }

    function harvest() public override nonReentrant {
        _harvest(msg.sender);
    }

    function _harvest(address user) private {
        distribute();
        updateReward(user);
        require(_depositions[user].reward > 0, "ERR_INSUFFICIENT_AMOUNT");
        Deposition memory deposition = _depositions[user];
        uint256 totalReward = deposition.reward;
        uint256 harvestAmount = totalReward;
        if (_pointExchangeRate > 0) {
            uint256 availablePoints = queryUserPoints(user);
            require(availablePoints > 0, "ERR_INSUFFICIENT_POINTS");
            uint256 equivalent_reward = (availablePoints * 100) / _pointExchangeRate;
            if (equivalent_reward >= totalReward) {
                _reducePoints(user, (totalReward * _pointExchangeRate) / 100);
            } else {
                _reducePoints(user, availablePoints);
                harvestAmount = equivalent_reward;
            }
        }
        deposition.reward = totalReward - harvestAmount;
        deposition.lastHarvestTime = block.timestamp;
        _depositions[user] = deposition;
        IDepositVault(_depositVault).withdraw(_rewardToken, user, harvestAmount);
        emit HarvestEvent(user, harvestAmount, block.timestamp);
    }

    function queryPendingReward(address user) public view returns (uint256 pending) {
        if (_depositions[user].amount > 0) {
            (, uint256 pendingRewardIndex) = queryPendingRewardIndex();
            uint256 rewardIndex = _rewardIndex + pendingRewardIndex;
            uint256 weight = _depositions[user].weight + _depositions[user].extraWeight;
            pending = (weight * (rewardIndex - _depositions[user].rewardIndex)) / INDEX_PRECISION;
        }
    }

    function updateReward(address user) public {
        uint256 pending = queryPendingReward(user);
        if (pending > 0) {
            _depositions[user].reward += pending;
        }
        _depositions[user].rewardIndex = _rewardIndex;
    }

    function queryUserPoints(address user) public view override returns (uint256) {
        return IRewardUnlocker(_rewardUnlocker).queryPoints(user);
    }

    function queryPendingRewardIndex()
        public
        view
        returns (uint256 vaultCumulativeDeposits, uint256 pendingRewardIndex)
    {
        if (_totalWeight > 0) {
            vaultCumulativeDeposits = IDepositVault(_depositVault).cumulativeDepositsOf(_rewardToken, address(this));
            uint256 reward = vaultCumulativeDeposits - _cumulativeDistributes;
            if (reward > 0) {
                pendingRewardIndex = (reward * INDEX_PRECISION) / _totalWeight;
            }
        }
    }

    function distribute() public {
        (uint256 vaultCumulativeDeposits, uint256 pendingRewardIndex) = queryPendingRewardIndex();
        if (vaultCumulativeDeposits > 0 && pendingRewardIndex > 0) {
            _rewardIndex += pendingRewardIndex;
            _cumulativeDistributes = vaultCumulativeDeposits;
        }
    }

    function emergencyWithdraw(address token, address to, uint256 amount) public onlyOwner {
        transferTokenTo(token, to, amount);
    }

    function _reducePoints(address user, uint256 points) private {
        IRewardUnlocker(_rewardUnlocker).reducePoints(user, points);
    }
}
