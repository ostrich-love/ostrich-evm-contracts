// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

abstract contract ERC1155Transferer {
    function transferERC1155From(address nft, address from, uint256 tokenId, uint256 amount) internal {
        IERC1155 erc721 = IERC1155(nft);
        require(erc721.balanceOf(from, tokenId) >= amount, "INSUFFICIENT_BALANCE_TO_TRANSFER");
        require(erc721.isApprovedForAll(from, address(this)), "NFT_NOT_APPROVED");
        erc721.safeTransferFrom(from, address(this), tokenId, amount, "");
    }

    function transferERC1155(address nft, address from, address to, uint256 tokenId, uint256 amount) internal {
        IERC1155 erc721 = IERC1155(nft);
        require(erc721.balanceOf(from, tokenId) >= amount, "INSUFFICIENT_BALANCE_TO_TRANSFER");
        require(erc721.isApprovedForAll(from, address(this)), "NFT_NOT_APPROVED");
        erc721.safeTransferFrom(from, to, tokenId, amount, "");
    }

    function transferERC1155To(address nft, address to, uint256 tokenId, uint256 amount) internal {
        IERC1155 erc721 = IERC1155(nft);
        require(erc721.balanceOf(address(this), tokenId) >= amount, "INSUFFICIENT_BALANCE_TO_TRANSFER");
        erc721.safeTransferFrom(address(this), to, tokenId, amount, "");
    }
}
