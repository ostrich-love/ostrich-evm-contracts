// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../common/TokenTransferer.sol";

contract Faucet is Ownable, TokenTransferer {
    mapping(address => uint) private _requestCounts;
    mapping(address => uint) private _lastRequestTimes;

    uint256 private _requestInterval;
    uint256 private _maxRequestCount;
    uint256 private _amountPerRequest;
    address private _token;

    constructor(address token) Ownable() {
        _requestInterval = 3600 * 24;
        _maxRequestCount = 10;
        _amountPerRequest = 100000 * 1e18;
        _token = token;
    }

    function updateRequestInterval(uint256 val) public onlyOwner {
        _requestInterval = val;
    }

    function updateMaxRequestCount(uint256 val) public onlyOwner {
        _maxRequestCount = val;
    }

    function updateAmountPerRequest(uint256 val) public onlyOwner {
        _amountPerRequest = val;
    }

    function updateToken(address val) public onlyOwner {
        _token = val;
    }

    function reqeust() public {
        address user = msg.sender;
        uint256 time = block.timestamp;
        require(_requestCounts[user] < _maxRequestCount, "COUNT_ERROR");
        require(time - _lastRequestTimes[user] > _requestInterval, "TIME_ERROR");
        transferTokenTo(_token, user, _amountPerRequest);
        _requestCounts[user] += 1;
        _lastRequestTimes[user] = time;
    }

    function queryUserInfo(address user) public view returns (uint256 requestCount, uint256 lastRequestTime) {
        return (_requestCounts[user], _lastRequestTimes[user]);
    }
}
