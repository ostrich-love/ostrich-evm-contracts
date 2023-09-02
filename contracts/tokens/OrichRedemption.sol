// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../common/ERC721Transferer.sol";
import "../common/TokenTransferer.sol";
import "../farm/IRewardUnlocker.sol";
import "./IOrichRedemption.sol";

contract OrichRedemption is IOrichRedemption, OwnableUpgradeable, ERC721Transferer, TokenTransferer {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public _orich;
    address public _bOrich;
    address public _fragment;
    address public _rewardUnlocker;

    uint256 private _nonces;

    RangeConfig private _rangeConfig;

    function initialize(address orich, address bOrich, address fragment, address rewardUnlocker) public initializer {
        __Ownable_init();
        _orich = orich;
        _bOrich = bOrich;
        _fragment = fragment;
        _rewardUnlocker = rewardUnlocker;
    }

    function updateRangeConfig(RangeConfig memory v) public onlyOwner {
        _rangeConfig = v;
    }

    function queryRangeConfig() public view override returns (RangeConfig memory) {
        return _rangeConfig;
    }

    function updateRewardUnlocker(address v) public onlyOwner {
        _rewardUnlocker = v;
    }

    function redeemOrich(uint256[] memory tokenIds) public override {
        require(tokenIds.length == 3, "INVLAID_PARAMS");
        address user = msg.sender;
        for (uint256 i; i < tokenIds.length; i++) {
            transferERC721From(_fragment, user, tokenIds[i]);
        }
        uint256 amount = _random(_rangeConfig.orichMinAmount, _rangeConfig.orichMaxAmount);
        transferTokenTo(_orich, user, amount);
        emit RedeemOrichEvent(user, tokenIds, amount, block.timestamp);
    }

    function redeemBOrich(uint256 tokenId) public override {
        address user = msg.sender;
        transferERC721From(_fragment, user, tokenId);
        uint256 amount = _random(_rangeConfig.bOrichMinAmount, _rangeConfig.bOrichMaxAmount);
        transferTokenTo(_bOrich, user, amount);
        emit RedeemBOrichEvent(user, tokenId, amount, block.timestamp);
    }

    function claimOrich(uint256 amount) public override {
        address user = msg.sender;
        uint256 points = queryUserPoints(user);
        require(points >= amount, "INSUFFICIENT_POINTS");
        _reducePoints(user, points);
        transferTokenFrom(_bOrich, user, amount);
        transferTokenTo(_orich, user, amount);
        emit ClaimOrichEvent(user, amount, amount, block.timestamp);
    }

    function _random(uint256 min, uint256 max) private returns (uint256) {
        uint n = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _nonces++)));
        return (n % (max - min + 1)) + min;
    }

    function emergencyWithdrawToken(address token, address to, uint256 amount) public onlyOwner {
        transferTokenTo(token, to, amount);
    }

    function emergencyWithdrawNft(address nft, address to, uint256[] memory tokenIds) public onlyOwner {
        for (uint i = 0; i < tokenIds.length; i++) {
            transferERC721To(nft, to, tokenIds[i]);
        }
    }

    function queryUserPoints(address user) public view override returns (uint256) {
        return IRewardUnlocker(_rewardUnlocker).queryPoints(user);
    }

    function _reducePoints(address user, uint256 points) private {
        IRewardUnlocker(_rewardUnlocker).reducePoints(user, points);
    }
}
