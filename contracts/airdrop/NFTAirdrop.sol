// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../libraries/Signature.sol";
import "./INFTAirdrop.sol";

interface ERC721 {
    function mintTo(address to) external returns (uint256 tokenId);
}

contract NFTAirdrop is INFTAirdrop, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    event ClaimEvent(address user, address nft, uint256 tokenId, uint256 timestamp);

    address public nft;
    address public constant SIGNER = 0xa4F8840A25E795c62B3584b53D84759e82dfFFFF;

    mapping(address => uint256) _userTokenIds;
    uint256 private _claimCount;

    function initialize(address nft_) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        nft = nft_;
    }

    function queryClaimCount() public view override returns (uint256 tokenId) {
        return _claimCount;
    }

    function queryUserTokenId(address user) public view override returns (uint256 tokenId) {
        return _userTokenIds[user];
    }

    function claim(bytes memory signature) public override nonReentrant whenNotPaused returns (uint256 tokenId) {
        require(Signature.getSigner(keccak256Hash(msg.sender), signature) == SIGNER, "INVALID_SIGNATURE");
        return _claim();
    }

    function claim2() public override nonReentrant whenNotPaused returns (uint256 tokenId) {
        return _claim();
    }

    function _claim() private returns (uint256 tokenId) {
        address user = msg.sender;
        require(_userTokenIds[user] == 0, "DUPLICATE_CLAIM");
        tokenId = ERC721(nft).mintTo(user);
        _claimCount++;
        _userTokenIds[user] = tokenId;
        emit ClaimEvent(user, nft, tokenId, block.timestamp);
    }

    function keccak256Hash(address user) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), user));
    }

    
}
