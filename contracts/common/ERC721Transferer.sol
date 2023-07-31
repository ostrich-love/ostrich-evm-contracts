// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

abstract contract ERC721Transferer {
    function transferERC721From(address nft, address from, uint256 tokenId) internal {
        IERC721 erc721 = IERC721(nft);
        require(erc721.ownerOf(tokenId) == from, "NFT_NOT_OWNED_BY_USER");
        require(
            erc721.isApprovedForAll(from, address(this)) || erc721.getApproved(tokenId) == address(this),
            "NFT_NOT_APPROVED"
        );
        erc721.transferFrom(from, address(this), tokenId);
    }

    function transferERC721(address nft, address from, address to, uint256 tokenId) internal {
        IERC721 erc721 = IERC721(nft);
        require(erc721.ownerOf(tokenId) == from, "NFT_NOT_OWNED_BY_USER");
        require(
            erc721.isApprovedForAll(from, address(this)) || erc721.getApproved(tokenId) == address(this),
            "NFT_NOT_APPROVED"
        );
        erc721.transferFrom(from, to, tokenId);
    }

    function transferERC721To(address nft, address to, uint256 tokenId) internal {
        require(IERC721(nft).ownerOf(tokenId) == address(this), "NFT_NOT_OWNED_BY_CONTRACT");
        IERC721(nft).transferFrom(address(this), to, tokenId);
    }
}
