// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IOrichAirdrop {
    event CliamEvent(uint256 batchId, address user, address referrer, uint256 amount, uint256 timestamp);
    struct ReferRecord {
        address user;
        uint256 amount;
        uint256 timestamp;
    }

    function userClaimsOf(address user) external view returns (uint256);

    function referRewardOf(address user) external view returns (uint256);

    function referRecordsOf(address user) external view returns (ReferRecord[] memory);

    function queryBatchSupplies() external view returns (uint256[] memory);

    function queryBatchClaims() external view returns (uint256[] memory batchClaims);

    function claim(address referrer, bytes memory signature) external;
}
