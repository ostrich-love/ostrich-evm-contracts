// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface INFTAirdrop {
    function queryUserTokenId(address user) external view returns (uint256 tokenId);

    function queryClaimCount() external view returns (uint256 tokenId);

    function claim(bytes memory signature) external returns (uint256 tokenId);

    function claim2() external returns (uint256 tokenId);
}
