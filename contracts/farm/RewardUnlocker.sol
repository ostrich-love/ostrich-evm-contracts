// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../common/TokenTransferer.sol";
import "./IRewardUnlocker.sol";

contract RewardUnlocker is ReentrancyGuardUpgradeable, TokenTransferer, OwnableUpgradeable, IRewardUnlocker {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _friendContracts;
    EnumerableSet.AddressSet private _poolTokens;

    mapping(address => Pool) _pools;
    mapping(address => UserStore) _userStores;

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }


    function addPool(address depositToken, uint256 unlockSpeed) public onlyOwner {
        Pool memory pool;
        pool.depositToken = depositToken;
        pool.unlockSpeed = unlockSpeed;
        pool.enabled = true;
        _pools[depositToken] = pool;
        _poolTokens.add(depositToken);
    }

    function updateUnlockSpeed(address depositToken, uint256 unlockSpeed) public onlyOwner {
        _pools[depositToken].unlockSpeed = unlockSpeed;
        _poolTokens.add(depositToken);
    }

    function disablePool(address depositToken) public onlyOwner {
        _pools[depositToken].enabled = false;
    }

    function queryPools() external view override returns (Pool[] memory pools) {
        pools = new Pool[](_poolTokens.length());
        for (uint256 i; i < pools.length; i++) {
            pools[i] = _pools[_poolTokens.at(i)];
        }
    }

    function addFridendContracts(address[] memory contracts) public onlyOwner {
        for (uint i; i < contracts.length; i++) {
            _friendContracts.add(contracts[i]);
        }
    }

    function removeFriendContracts(address[] memory contracts) public onlyOwner {
        for (uint i; i < contracts.length; i++) {
            _friendContracts.add(contracts[i]);
        }
    }

    function queryFriendContracts() public view returns (address[] memory friendContracts) {
        friendContracts = new address[](_friendContracts.length());
        for (uint256 i; i < friendContracts.length; i++) {
            friendContracts[i] = _friendContracts.at(i);
        }
    }

    function deposit(address token, uint256 amount) public override nonReentrant {
        require(_pools[token].enabled, "UNSUPPORTED_POOL");
        _pools[token].totalDeposits += amount;
        address user = msg.sender;
        if (_userStores[user].lastCalculateBlock > 0) {
            _updatePoints(user);
        } else {
            _userStores[user].lastCalculateBlock = block.number;
        }
        _userStores[user].deposits[token] += amount;
        transferTokenFrom(token, user, amount);
    }

    function withdraw(address token, uint256 amount) public override nonReentrant {
        address user = msg.sender;
        _updatePoints(user);
        require(_pools[token].totalDeposits >= amount, "ERR_INSUFFICIENT_AMOUNT");
        _pools[token].totalDeposits -= amount;

        require(_userStores[user].deposits[token] >= amount, "ERR_INSUFFICIENT_AMOUNT");
        _userStores[user].deposits[token] -= amount;
        transferTokenTo(token, user, amount);
    }

    function reducePoints(address user, uint256 amount) public override {
        require(_friendContracts.contains(msg.sender), "NOT_FRIEND_CONTRACT");
        _updatePoints(user);
        require(_userStores[user].points >= amount, "ERR_INSUFFICIENT_POINTS");
        _userStores[user].points -= amount;
    }

    function queryPoints(address user) public view override returns (uint256) {
        return _userStores[user].points + queryPendingPoints(user);
    }

    function queryBlockNumber() public view returns (uint256) {
        return block.number;
    }

    function queryUserDepositions(
        address user
    ) external view override returns (address[] memory tokens, uint256[] memory amounts) {
        tokens = new address[](_poolTokens.length());
        amounts = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            address token = _poolTokens.at(i);
            tokens[i] = token;
            amounts[i] = _userStores[user].deposits[token];
        }
    }

    function queryPendingPoints(address user) public view returns (uint256 points) {
        uint256 lastBlockHeight = _userStores[user].lastCalculateBlock;
        uint256 blockHeight = block.number;
        if (blockHeight > lastBlockHeight) {
            uint256 diff = blockHeight - lastBlockHeight;
            for (uint i = 0; i < _poolTokens.length(); i++) {
                address token = _poolTokens.at(i);
                uint256 amount = _userStores[user].deposits[token];
                if (amount > 0) {
                    points += (_pools[token].unlockSpeed * diff * amount) / 1e9;
                }
            }
        }
    }

    function queryUserView(address user) external view override returns (UserView memory userView) {
        DepositView[] memory deposits = new DepositView[](_poolTokens.length());
        for (uint256 i; i < deposits.length; i++) {
            address token = _poolTokens.at(i);
            deposits[i] = DepositView({ token: token, amount: _userStores[user].deposits[token] });
        }
        userView.user = user;
        userView.deposits = deposits;
        userView.points = _userStores[user].points;
        userView.pendingPoints = queryPendingPoints(user);
        userView.lastCalculateBlock = _userStores[user].lastCalculateBlock;
    }

    function _updatePoints(address user) private {
        if (_userStores[user].lastCalculateBlock > block.number) {
            _userStores[user].lastCalculateBlock = block.number;
            return;
        }
        _userStores[user].points += queryPendingPoints(user);
        _userStores[user].lastCalculateBlock = block.number;
    }

    function emergencyWithdraw(address token, address to, uint256 amount) public onlyOwner {
        transferTokenTo(token, to, amount);
    }
}
