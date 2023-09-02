// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../common/TokenTransferer.sol";
import "../libraries/Signature.sol";
import "./IOrichAirdrop.sol";


contract OrichAirdrop is
    IOrichAirdrop,
    TokenTransferer,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    address public orich;
    address public constant SIGNER = 0xa4F8840A25E795c62B3584b53D84759e82dfFFFF;
    uint256 public constant USERS_PER_BATCH = 31257;

    uint256[] private _batchSupplies;
    mapping(uint256 => uint256) private _batchClaims;
    mapping(address => uint256) public override userClaimsOf;
    mapping(address => uint256) public override referRewardOf;
    mapping(address => ReferRecord[]) private _referRecordsOf;

    function initialize(address orich_) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        orich = orich_;
    }

    function referRecordsOf(address user) external view override returns (ReferRecord[] memory) {
        return _referRecordsOf[user];
    }

    function updateBatchSupplies(uint256[] memory v) public onlyOwner {
        _batchSupplies = v;
    }

    function queryBatchSupplies() public view override returns (uint256[] memory) {
        return _batchSupplies;
    }

    function queryBatchClaims() public view override returns (uint256[] memory batchClaims) {
        batchClaims = new uint256[](_batchSupplies.length);
        for (uint256 i; i < batchClaims.length; i++) {
            batchClaims[i] = _batchClaims[i];
        }
    }

    function claim(address referrer, bytes memory signature) public override nonReentrant whenNotPaused {
        require(Signature.getSigner(keccak256Hash(msg.sender), signature) == SIGNER, "INVALID_SIGNATURE");
        return _claim(referrer);
    }

    function _claim(address referrer) private {
        address user = msg.sender;
        require(user != referrer, "INVALID_REFERER");
        require(userClaimsOf[user] == 0, "DUPLICATE_CLAIM");
        for (uint256 i; i < _batchSupplies.length; i++) {
            uint256 amount = _batchSupplies[i] / USERS_PER_BATCH;
            if (_batchClaims[i] + amount <= _batchSupplies[i]) {
                _batchClaims[i] += amount;
                userClaimsOf[user] = amount;
                transferTokenTo(orich, user, amount);
                if (referrer != address(0)) {
                    uint256 rewardAmount = (amount * 5) / 100;
                    referRewardOf[referrer] += rewardAmount;
                    _referRecordsOf[referrer].push(
                        ReferRecord({ user: user, amount: amount, timestamp: block.timestamp })
                    );
                    transferTokenTo(orich, referrer, rewardAmount);
                }
                emit CliamEvent(i, user, referrer, amount, block.timestamp);
                return;
            }
        }
        revert("AIRDROP_FINISHED");
    }

    function keccak256Hash(address user) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), user));
    }

    function emergencyWithdraw(address token, address to, uint256 amount) public onlyOwner {
        transferTokenTo(token, to, amount);
    }
}
