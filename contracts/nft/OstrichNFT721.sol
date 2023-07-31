// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../common/Minable.sol";
import "./IOstrichNFT721.sol";

contract OstrichNFT721 is ERC721EnumerableUpgradeable, ERC2981Upgradeable, OwnableUpgradeable, Minable, IOstrichNFT {
    using Strings for uint256;
    string public baseURI;
    string public uriSuffix;
    uint256 public nextTokenId;

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(IERC165Upgradeable, ERC721EnumerableUpgradeable, ERC2981Upgradeable) returns (bool) {
        return
            interfaceId == type(IOstrichNFT).interfaceId ||
            ERC721EnumerableUpgradeable.supportsInterface(interfaceId) ||
            ERC721EnumerableUpgradeable.supportsInterface(interfaceId) ||
            ERC2981Upgradeable.supportsInterface(interfaceId);
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        string memory uriSuffix_
    ) public initializer {
        __Ownable_init();
        __ERC2981_init();
        __ERC721_init(name_, symbol_);
        baseURI = baseURI_;
        uriSuffix = uriSuffix_;
        nextTokenId = 1;
        addMinter(msg.sender);
    }

    function updateNextTokenId(uint256 val) public onlyOwner {
        nextTokenId = val;
    }

    function updateBaseURI(string memory val) public onlyOwner {
        baseURI = val;
    }

    function mintTo(address to) public override onlyMinter returns (uint256 tokenId) {
        return _mintTo(to);
    }

    function _mintTo(address to) private returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _mint(to, tokenId);
    }

    function batchMintTo(address to, uint256 count) public onlyMinter returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](count);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenIds[i] = _mintTo(to);
        }
    }

    function burn(uint256 tokenId) public virtual override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "INVALID_ACCESS");
        _burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

    function tokensOfOwner(address owner) public view override returns (uint256[] memory tokenIds) {
        uint256 balance = balanceOf(owner);
        tokenIds = new uint256[](balance);
        for (uint256 i; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override(ERC721Upgradeable, IERC721MetadataUpgradeable) returns (string memory) {
        require(_exists(tokenId), "INVALID_TOKEN_ID");
        return string(abi.encodePacked(baseURI, tokenId.toString(), uriSuffix));
    }

    function exists(uint256 tokenId) external view override returns (bool) {
        return _exists(tokenId);
    }

    function feeDenominator() external pure returns (uint96) {
        return _feeDenominator();
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "INVALID_ACCESS");
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "INVALID_ACCESS");
        _resetTokenRoyalty(tokenId);
    }
}
