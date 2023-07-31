// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./IOracle.sol";

contract OstrichOracle is OwnableUpgradeable, IOracle {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) private _assetPrices;
    EnumerableSet.AddressSet private _assets;

    function initialize() public initializer {
        __Ownable_init();
    }

    function getAssets() external view returns (address[] memory assets) {
        assets = new address[](_assets.length());
        for (uint256 i; i < assets.length; i++) {
            assets[i] = _assets.at(i);
        }
    }

    function updatePrices(address[] memory assets, uint256[] memory prices) external {
        require(assets.length == prices.length, "INVALID_PRAMETERS");
        for (uint256 i; i < assets.length; i++) {
            (address asset, uint256 price) = (assets[i], prices[i]);
            _assets.add(asset);
            _assetPrices[asset] = price;
        }
    }

    function queryAllPrices() public view returns (address[] memory assets, uint256[] memory prices) {
        assets = new address[](_assets.length());
        prices = new uint256[](assets.length);
        for (uint256 i; i < assets.length; i++) {
            address asset = _assets.at(i);
            assets[i] = asset;
            prices[i] = _assetPrices[asset];
        }
    }

    function queryPrice(address asset) public view override returns (uint256 price) {
        price = _assetPrices[asset];
    }
}
