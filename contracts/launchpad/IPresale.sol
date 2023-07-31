// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IPresale {
    struct BuyRecord {
        address currency;
        uint256 currencyAmount;
        uint256 usdAmount;
        uint256 tokenAmount;
        uint256 timestamp;
    }

    struct ClaimRecord {
        uint256 tokenAmount;
        uint256 timestamp;
    }

    struct UserInfo {
        uint256 tokenAmount;
        uint256 totalPayment;
        BuyRecord[] buyRecords;
        ClaimRecord[] claimRecords;
    }

    event BuyEvent(
        address indexed user,
        address currency,
        uint256 currencyAmount,
        uint256 usdAmount,
        uint256 tokenAmount,
        uint256 timestamp
    );

    event ClaimEvent(address indexed user, uint256 index, uint256 amount, uint256 timestamp);

    function queryUserInfo(address user) external view returns (UserInfo memory);

    function buy(address currency, uint256 amount, bytes memory signature) external payable;

    function queryPrice(address currency) external view returns (uint256);

    function queryUsdAmount(address currency, uint256 amount) external view returns (uint256);

    function claim() external;

    function queryGlobalView()
        external
        view
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
        );
}
