// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IOrichRedemption {
    struct RangeConfig {
        uint256 orichMinAmount;
        uint256 orichMaxAmount;
        uint256 bOrichMinAmount;
        uint256 bOrichMaxAmount;
    }

    event RedeemOrichEvent(address user, uint256[] tokenIds, uint256 orichAmount, uint256 timestamp);
    event RedeemBOrichEvent(address user, uint256 tokenId, uint256 bOrichAmount, uint256 timestamp);
    event ClaimOrichEvent(address user, uint256 bOrichAmount, uint256 orichAmount, uint256 timestamp);

    function queryRangeConfig() external view returns (RangeConfig memory);

    function redeemOrich(uint256[] memory tokenIds) external;

    function redeemBOrich(uint256 tokenId) external;

    function claimOrich(uint256 bOrichAmount) external;

    function queryUserPoints(address user) external view returns (uint256);
}
