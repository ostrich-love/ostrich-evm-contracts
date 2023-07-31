// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../common/Minable.sol";
import "./IERC1155Mintable.sol";
import "./IERC1155Burnable.sol";

contract OstrichNFT1155 is ERC1155SupplyUpgradeable, OwnableUpgradeable, Minable, IERC1155Mintable, IERC1155Burnable {
    using Strings for uint256;
    string public baseURI;

    function initialize(string memory uri_) public initializer {
        __Ownable_init();
        __ERC1155_init(uri_);
        addMinter(msg.sender);
        baseURI = uri_;
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) public override onlyMinter {
        _mint(to, id, amount, data);
    }

    function burn(uint256 id, uint256 amount) public override {
        _burn(msg.sender, id, amount);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function updateBaseURI(string memory val) public onlyOwner {
        baseURI = val;
    }
}
