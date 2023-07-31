// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../libraries/SafeDecimalMath.sol";
import "./IOracle.sol";

contract ChainlinkOracle is Ownable, IOracle {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    uint256 private constant DECIMALS18 = 18;

    mapping(address => address) private _feeders;
    EnumerableSet.AddressSet private _assets;

    constructor() Ownable() {}


    function updateFeeders(address[] calldata assets, address[] calldata feeders) public onlyOwner {
        require(assets.length == feeders.length, "Invalid parameters");
        for (uint256 i = 0; i < assets.length; i++) {
            _feeders[assets[i]] = feeders[i];
            _assets.add(assets[i]);
        }
    }

    function removeFeeders(address[] calldata assets) public onlyOwner {
        for (uint256 i = 0; i < assets.length; i++) {
            delete _feeders[assets[i]];
            _assets.remove(assets[i]);
        }
    }

    function queryFeeders() public view returns (address[] memory assets, address[] memory feeders) {
        assets = new address[](_assets.length());
        feeders = new address[](assets.length);
        for (uint256 i; i < assets.length; i++) {
            assets[i] = _assets.at(i);
            feeders[i] = _feeders[assets[i]];
        }
    }

    function toDecimals18(uint256 value, uint256 decimals) private pure returns (uint256) {
        if (decimals == DECIMALS18) {
            return value;
        } else if (decimals < DECIMALS18) {
            return value.mul(10 ** DECIMALS18.sub(decimals));
        } else {
            return value.div(10 ** decimals.sub(DECIMALS18));
        }
    }

    function queryPrices(address[] memory assets) external view returns (uint256[] memory prices) {
        prices = new uint256[](assets.length);
        for (uint256 i; i < assets.length; i++) {
            prices[i] = _queryPriceByAsset(assets[i]);
        }
    }

    function queryPrice(address asset) external view override returns (uint256 price) {
        return _queryPriceByAsset(asset);
    }

    function queryPricesByFeeders(address[] memory feeders) external view returns (uint256[] memory prices) {
        prices = new uint256[](feeders.length);
        for (uint256 i; i < feeders.length; i++) {
            prices[i] = _queryPriceByFeeder(feeders[i]);
        }
    }

    function queryPriceByFeeder(address feeder) external view returns (uint256 price) {
        return _queryPriceByFeeder(feeder);
    }

    function _queryPriceByFeeder(address feeder) private view returns (uint256 price) {
        if (feeder != address(0)) {
            AggregatorV3Interface aggregator = AggregatorV3Interface(feeder);
            (, int256 answer, , , ) = aggregator.latestRoundData();
            if (answer > 0) {
                return toDecimals18(uint256(answer), uint256(aggregator.decimals()));
            }
        }
        return 0;
    }

    function _queryPriceByAsset(address asset) private view returns (uint256 price) {
        return _queryPriceByFeeder(_feeders[asset]);
    }
}
