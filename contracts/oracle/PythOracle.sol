// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "./IOracle.sol";


contract PythOracle is OwnableUpgradeable, IOracle {
    using EnumerableSet for EnumerableSet.AddressSet;

    address private _pyth;

    mapping(address => bytes32) private _feeders;

    EnumerableSet.AddressSet private _tokens;

    EnumerableSet.AddressSet private _usdTokens;

    function initialize(address pyth) public initializer {
        __Ownable_init();
        _pyth = pyth;
    }

    function queryPythPrices(bytes32[] memory feedIds) public view returns (PythStructs.Price[] memory prices) {
        prices = new PythStructs.Price[](feedIds.length);
        for (uint i; i < feedIds.length; i++) {
            prices[i] = queryPythPrice(feedIds[i]);
        }
    }

    function queryPythPrice(bytes32 feedId) public view returns (PythStructs.Price memory) {
        return IPyth(_pyth).getPriceUnsafe(feedId);
    }

    function queryPrice(address token) public view override returns (uint256 price) {
        if (_usdTokens.contains(token)) {
            return 1e18;
        }
        bytes32 feedId = _feeders[token];
        PythStructs.Price memory p = queryPythPrice(feedId);
        if (p.price > 0) {
            return uint256(int256(p.price)) * (10 ** uint256(int256(18 + p.expo)));
        }
        return 0;
    }

    function updateFeeders(address[] calldata tokens, bytes32[] calldata feeders) public onlyOwner {
        require(tokens.length == feeders.length, "Invalid parameters");
        for (uint256 i = 0; i < tokens.length; i++) {
            _feeders[tokens[i]] = feeders[i];
            _tokens.add(tokens[i]);
        }
    }

    function removeFeeders(address[] calldata tokens) public onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            delete _feeders[tokens[i]];
            _tokens.remove(tokens[i]);
        }
    }

    function queryFeeders() public view returns (address[] memory tokens, bytes32[] memory feeders) {
        tokens = new address[](_tokens.length());
        feeders = new bytes32[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            tokens[i] = _tokens.at(i);
            feeders[i] = _feeders[tokens[i]];
        }
    }

    function addUsdTokens(address[] memory items) public onlyOwner {
        for (uint256 i; i < items.length; i++) {
            _usdTokens.add(items[i]);
        }
    }

    function removeUsdTokens(address[] memory items) public onlyOwner {
        for (uint256 i; i < items.length; i++) {
            _usdTokens.remove(items[i]);
        }
    }

    function queryUsdTokens() external view returns (address[] memory usdTokens) {
        usdTokens = new address[](_usdTokens.length());
        for (uint256 i; i < usdTokens.length; i++) {
            usdTokens[i] = _usdTokens.at(i);
        }
    }
}
