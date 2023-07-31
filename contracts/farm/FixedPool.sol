// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../common/TokenTransferer.sol";
import "../common/ERC721Transferer.sol";
import "./IFixedPool.sol";
import "../vault/IDepositVault.sol";
import "../vault/IRewardVault.sol";

contract FixedPool is OwnableUpgradeable, ReentrancyGuardUpgradeable, TokenTransferer, ERC721Transferer, IFixedPool {
    using EnumerableSet for EnumerableSet.UintSet;
    uint256 constant INDEX_PRECISION = 1e12;

    address private _depositToken;
    address private _rewardToken;

    uint256 private _startTime;
    uint256 private _endTime;
    uint256 private _weeklyReward;
    uint256 private _lockUnitSpan;

    uint256 private _rewardIndex;
    uint256 private _lastDistributeTime;
    uint256 private _totalDeposits;
    uint256 private _totalWeight;
    uint256 private _nextDepositId;

    mapping(uint256 => Deposition) private _depositions;
    mapping(address => EnumerableSet.UintSet) private _userDepositionIds;

    address private _accelerateNFT;
    uint256 private _accelerateRate;
    mapping(address => uint256) private _userAccelerateNFTs;
    address private _depositVault;
    address private _rewardVault;

    function initialize(
        address depositToken,
        address rewardToken,
        address depositVault,
        address rewardVault
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        _depositToken = depositToken;
        _rewardToken = rewardToken;
        _depositVault = depositVault;
        _rewardVault = rewardVault;
        _nextDepositId = 1;
    }

    function updateDepositVault(address val) public onlyOwner {
        _depositVault = val;
        uint256 balance = IERC20(_depositToken).balanceOf(address(this));
        if (balance > 0) {
            IERC20(_depositToken).transfer(_depositVault, balance);
            IDepositVault(_depositVault).deposit(_depositToken, address(this));
        }
    }

    function updateRewardVault(address val) public onlyOwner {
        _rewardVault = val;
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
        distribute();
        address user = msg.sender;
        require(_accelerateNFT != address(0), "ACCELERATE_NOT_SUPPORTED");
        require(_userAccelerateNFTs[user] == 0, "DUPLICATE_DEPOSIT_ACCELERATE_NFT");
        _userAccelerateNFTs[user] = tokenId;
        for (uint256 i; i < _userDepositionIds[user].length(); i++) {
            uint256 depositId = _userDepositionIds[user].at(i);
            _updateReward(depositId);
            uint256 extraWeight = (_depositions[depositId].weight * _accelerateRate) / 100;
            _totalWeight += extraWeight;
            _depositions[depositId].extraWeight = extraWeight;
        }
        transferERC721From(_accelerateNFT, user, tokenId);
    }

    function withdrawAccelerateNFT(uint256 tokenId) public override nonReentrant {
        distribute();
        address user = msg.sender;
        require(_accelerateNFT != address(0), "ACCELERATE_NOT_SUPPORTED");
        require(_userAccelerateNFTs[user] == tokenId, "NO_ACCELERATE_NFT_DEPOSITED");
        _userAccelerateNFTs[user] = 0;
        for (uint256 i; i < _userDepositionIds[user].length(); i++) {
            uint256 depositId = _userDepositionIds[user].at(i);
            _updateReward(depositId);
            _totalWeight -= _depositions[depositId].extraWeight;
            _depositions[depositId].extraWeight = 0;
        }
        transferERC721To(_accelerateNFT, user, tokenId);
    }

    function queryUserDepositions(address user) external view override returns (Deposition[] memory depositions) {
        depositions = new Deposition[](_userDepositionIds[user].length());
        for (uint256 i; i < depositions.length; i++) {
            Deposition memory deposition = _depositions[_userDepositionIds[user].at(i)];
            deposition.reward += queryPendingReward(deposition.depositId);
            depositions[i] = deposition;
        }
    }

    function queryPool()
        public
        view
        override
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
        )
    {
        return (
            _depositToken,
            _rewardToken,
            _startTime,
            _endTime,
            _weeklyReward,
            _lockUnitSpan,
            _rewardIndex,
            _lastDistributeTime,
            _totalDeposits,
            _totalWeight,
            _nextDepositId,
            _depositVault,
            _rewardVault
        );
    }

    function updateStartTime(uint256 val) public onlyOwner {
        _startTime = val;
    }

    function updateEndTime(uint256 val) public onlyOwner {
        _endTime = val;
    }

    function updateWeeklyReward(uint256 val) public onlyOwner {
        _weeklyReward = val;
    }

    function updateLockUnitSpan(uint256 val) public onlyOwner {
        _lockUnitSpan = val;
    }

    function deposit(uint256 amount, uint256 lockUnits) public payable override nonReentrant {
        distribute();
        address user = msg.sender;
        uint256 timestamp = block.timestamp;
        require(timestamp >= _startTime, "ERR_POOL_NOT_STARTED");
        require(timestamp <= _endTime, "ERR_POOL_ENDED");
        require(lockUnits > 0 && lockUnits <= 52, "ERR_INVALID_PARAM");
        uint256 depositId = _nextDepositId;
        uint256 weight = calculateWeight(amount, lockUnits);

        uint256 extraWeight;
        if (_userAccelerateNFTs[user] != 0) {
            extraWeight = (weight * _accelerateRate) / 100;
        }
        Deposition memory deposition = Deposition({
            depositId: depositId,
            amount: amount,
            rewardIndex: _rewardIndex,
            reward: 0,
            lockUnits: lockUnits,
            depositTime: timestamp,
            weight: weight,
            extraWeight: extraWeight
        });
        _userDepositionIds[user].add(depositId);
        _depositions[depositId] = deposition;
        transferToken(_depositToken, user, _depositVault, amount);
        IDepositVault(_depositVault).deposit(_depositToken, address(this));
        _totalDeposits = _totalDeposits + amount;
        _totalWeight += (weight + extraWeight);
        _nextDepositId = _nextDepositId + 1;
        emit DepositEvent(user, depositId, amount, lockUnits, weight, timestamp);
        emit TotalDepositsChanged(_depositToken, _totalDeposits, timestamp);
    }

    function withdraw(uint256 depositId) public override nonReentrant {
        require(_userDepositionIds[msg.sender].contains(depositId), "INALID_DEPOIST_ID");
        distribute();
        _updateReward(depositId);
        _harvest(depositId);
        _withdraw(depositId);
    }

    function harvest(uint256 depositId) public override nonReentrant {
        require(_userDepositionIds[msg.sender].contains(depositId), "INALID_DEPOIST_ID");
        distribute();
        _updateReward(depositId);
        _harvest(depositId);
    }

    function _harvest(uint256 depositId) private {
        uint256 timestamp = block.timestamp;
        uint256 harvestAmount = _depositions[depositId].reward;
        if (harvestAmount > 0) {
            _depositions[depositId].reward = 0;
            IRewardVault(_rewardVault).transferTo(_rewardToken, msg.sender, harvestAmount);
        }
        emit HarvestEvent(msg.sender, harvestAmount, timestamp);
    }

    function _withdraw(uint256 depositId) private {
        uint256 timestamp = block.timestamp;
        Deposition memory deposition = _depositions[depositId];
        require(timestamp - deposition.depositTime > deposition.lockUnits * _lockUnitSpan, "ERR_INVALID_WITHDRAW_TIME");
        _totalDeposits = _totalDeposits - deposition.amount;
        _totalWeight -= (deposition.weight + deposition.extraWeight);
        IDepositVault(_depositVault).withdraw(_depositToken, msg.sender, deposition.amount);
        delete _depositions[deposition.depositId];
        _userDepositionIds[msg.sender].remove(depositId);
        emit WithdrawEvent(msg.sender, deposition.depositId, deposition.amount, timestamp);
        emit TotalDepositsChanged(_depositToken, _totalDeposits, timestamp);
    }

    function queryPendingDistributeReward() public view returns (uint256 reward) {
        uint256 timestamp = block.timestamp;
        if (timestamp > _lastDistributeTime && _lastDistributeTime > 0 && _totalWeight > 0) {
            reward = ((timestamp - _lastDistributeTime) * _weeklyReward) / 3600 / 24 / 7;
        }
    }

    function queryPendingRewardIndex() public view returns (uint256 pendingRewardIndex) {
        uint256 reward = queryPendingDistributeReward();
        if (reward > 0) {
            pendingRewardIndex = (reward * INDEX_PRECISION) / _totalWeight;
        }
    }

    function distribute() public {
        _rewardIndex += queryPendingRewardIndex();
        _lastDistributeTime = block.timestamp;
    }

    function calculateWeight(uint256 amount, uint256 lockUnits) public pure returns (uint256) {
        return (amount + (amount * (lockUnits - 1) * 2) / 10);
    }

    function queryPendingReward(uint256 depositId) public view returns (uint256 pendingReward) {
        Deposition memory deposition = _depositions[depositId];
        if (deposition.weight > 0) {
            uint256 rewardIndex = _rewardIndex + queryPendingRewardIndex();
            uint256 weight = deposition.weight + deposition.extraWeight;
            pendingReward = (weight * (rewardIndex - deposition.rewardIndex)) / INDEX_PRECISION;
        }
    }

    function _updateReward(uint256 depositId) private {
        uint256 reward = queryPendingReward(depositId);
        if (reward > 0) {
            _depositions[depositId].reward += reward;
        }
        _depositions[depositId].rewardIndex = _rewardIndex;
    }

    function emergencyWithdraw(address token, address to, uint256 amount) public onlyOwner {
        transferTokenTo(token, to, amount);
    }
}
