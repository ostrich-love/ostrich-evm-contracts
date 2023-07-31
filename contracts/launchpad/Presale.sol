// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../common/TokenTransferer.sol";
import "../libraries/Signature.sol";
import "../oracle/IOracle.sol";
import "./IPresale.sol";

interface ERC20 {
    function decimals() external pure returns (uint8);
}

contract Presale is IPresale, TokenTransferer, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    address public constant SIGNER = 0xa4F8840A25E795c62B3584b53D84759e82dfFFFF;

    address private _oracle;
    address private _feeWallet;
    address private _token;
    uint256 private _tokenSupply;
    uint256 private _tokenSales;
    uint256 private _claimStartTime;
    uint256 private _minBuyAmount;
    uint256 private _maxBuyAmount;
    uint256 private _privatePrice;
    uint256 private _publicPrice;
    uint256 private _startTime;

    uint256[] private _claimTimes;
    mapping(address => UserInfo) private _userInfos;
    EnumerableSet.AddressSet private _currencies;

    function initialize(
        address token,
        address oracle,
        address feeWallet,
        uint256 tokenSupply,
        uint256 minBuyAmount,
        uint256 maxBuyAmount,
        uint256 privatePrice,
        uint256 publicPrice,
        uint256 startTime
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        _token = token;
        _oracle = oracle;
        _feeWallet = feeWallet;
        _tokenSupply = tokenSupply;
        _minBuyAmount = minBuyAmount;
        _maxBuyAmount = maxBuyAmount;
        _privatePrice = privatePrice;
        _publicPrice = publicPrice;
        _startTime = startTime;
    }

    function updateStartTime(uint256 val) public onlyOwner {
        _startTime = val;
    }

    function updateOracle(address val) public onlyOwner {
        _oracle = val;
    }

    function updateFeeWallet(address val) public onlyOwner {
        _feeWallet = val;
    }

    function updateTokenSupply(uint256 val) public onlyOwner {
        _tokenSupply = val;
    }

    function updateMinBuyPrice(uint256 val) public onlyOwner {
        _minBuyAmount = val;
    }

    function updateClaimStartTime(uint256 val) public onlyOwner {
        _claimStartTime = val;
    }

    function updateMaxBuyPrice(uint256 val) public onlyOwner {
        _maxBuyAmount = val;
    }

    function updatePrivatePrice(uint256 val) public onlyOwner {
        _privatePrice = val;
    }

    function updatePublicPrice(uint256 val) public onlyOwner {
        _publicPrice = val;
    }

    function updateMaxBuyAmount(uint256 val) public onlyOwner {
        _maxBuyAmount = val;
    }

    function updateMinBuyAmount(uint256 val) public onlyOwner {
        _minBuyAmount = val;
    }

    function updateClaimTimes(uint256[] memory times) public onlyOwner {
        require(times.length == 4, "INVALID_TIMES");
        _claimTimes = times;
    }

    function queryUserInfo(address user) public view override returns (UserInfo memory) {
        return _userInfos[user];
    }

    function buy(
        address currency,
        uint256 amount,
        bytes memory signature
    ) external payable override whenNotPaused nonReentrant {
        if (signature.length == 65) {
            require(Signature.getSigner(keccak256Hash(msg.sender), signature) == SIGNER, "INVALID_SIGNATURE");
            _buy(msg.sender, currency, _privatePrice, amount);
        } else {
            _buy(msg.sender, currency, _publicPrice, amount);
        }
    }

    function queryPrice(address currency) public view override returns (uint256) {
        return IOracle(_oracle).queryPrice(currency);
    }

    function queryUsdAmount(address currency, uint256 amount) public view override returns (uint256) {
        uint8 decimals = currency == address(0) ? 18 : ERC20(currency).decimals();
        return (queryPrice(currency) * amount) / 10 ** uint256(decimals);
    }

    function _buy(address user, address currency, uint256 price, uint256 amount) private {
        require(block.timestamp >= _startTime, "NOT_STARTED_YET");
        require(_currencies.contains(currency), "UNSUPPORTED_CURRENCY");
        require(_tokenSales < _tokenSupply, "FINISHED");
        uint256 usdAmount = queryUsdAmount(currency, amount);
        uint256 tokenAmount = (usdAmount * 1e18) / price;
        require(usdAmount > 0, "CURRENCY_NOT_SUPPORTED");
        require(usdAmount >= _minBuyAmount, "INSUFFICIENT_AMOUNT");
        require(_userInfos[user].totalPayment + usdAmount <= _maxBuyAmount, "EXCEED_MAX_AMOUNT");
        _userInfos[user].tokenAmount += tokenAmount;
        _tokenSales += tokenAmount;
        _userInfos[user].totalPayment += usdAmount;
        _userInfos[user].buyRecords.push(
            BuyRecord({
                currency: currency,
                currencyAmount: amount,
                usdAmount: usdAmount,
                tokenAmount: tokenAmount,
                timestamp: block.timestamp
            })
        );
        transferTokenFrom(currency, user, amount);
        transferTokenTo(currency, _feeWallet, amount);
        if (_tokenSales >= _tokenSupply) {
            _claimStartTime = block.timestamp;
        }
        emit BuyEvent(user, currency, amount, usdAmount, tokenAmount, block.timestamp);
    }

    function claim() public override whenNotPaused nonReentrant {
        require(_claimStartTime > 0, "CLAIM_NOT_STARTED");
        require(_claimTimes.length == 4, "INVALID_CLAIM_TIME_SETTING");
        address user = msg.sender;
        uint256 currentTimestamp = block.timestamp;
        uint256 timeDiff = currentTimestamp - _claimStartTime;
        uint256 claimAmount;
        uint256 tokenAmount = _userInfos[user].tokenAmount;
        require(tokenAmount > 0, "NOTHING_TO_CLAIM");
        for (uint256 i = _userInfos[user].claimRecords.length; i <= 3; i++) {
            if (timeDiff < _claimTimes[i]) break;
            uint256 amount = i == 0 ? tokenAmount / 2 : tokenAmount / 6;
            claimAmount += amount;
            _userInfos[user].claimRecords.push(ClaimRecord({ tokenAmount: amount, timestamp: currentTimestamp }));
            emit ClaimEvent(user, i, amount, currentTimestamp);
        }
        require(claimAmount > 0, "CLAIM_AMOUNT_ZERO");
        transferTokenTo(_token, user, claimAmount);
    }

    function keccak256Hash(address user) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), user));
    }

    function addCurrencis(address[] memory items) public onlyOwner {
        for (uint256 i; i < items.length; i++) {
            _currencies.add(items[i]);
        }
    }

    function removeCurrencis(address[] memory items) public onlyOwner {
        for (uint256 i; i < items.length; i++) {
            _currencies.remove(items[i]);
        }
    }

    function queryCurrencies() public view returns (address[] memory currencies) {
        currencies = new address[](_currencies.length());
        for (uint256 i; i < currencies.length; i++) {
            currencies[i] = _currencies.at(i);
        }
    }

    function queryGlobalView()
        external
        view
        override
        returns (
            address oracle,
            address feeWallet,
            address token,
            uint256 tokenSupply,
            uint256 tokenSales,
            uint256 claimStartTime,
            uint256 privatePrice,
            uint256 publicPrice,
            uint256 minBuyAmount,
            uint256 maxBuyAmount,
            uint256 startTime,
            address[] memory currencies,
            uint256[] memory claimTimes
        )
    {
        oracle = _oracle;
        feeWallet = _feeWallet;
        token = _token;
        tokenSupply = _tokenSupply;
        tokenSales = _tokenSales;
        claimStartTime = _claimStartTime;
        privatePrice = _privatePrice;
        publicPrice = _publicPrice;
        minBuyAmount = _minBuyAmount;
        maxBuyAmount = _maxBuyAmount;
        startTime = _startTime;
        currencies = queryCurrencies();
        claimTimes = _claimTimes;
    }
}
