// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IMarketplace {
    struct FeeConfig {
        uint256 rate;
        address receiver;
    }

    struct ListRequest {
        uint256 id;
        uint256 nftType;
        address nft;
        uint256 tokenId;
        uint256 amount;
        address currency;
        uint256 price;
        uint256 deadline;
        address seller;
        bytes signature;
    }

    struct TransferRequest {
        address to;
        uint256 nftType;
        address nft;
        uint256 tokenId;
        uint256 amount;
    }

    event BuyEvent(
        uint256 id,
        uint256 nftType,
        address nft,
        uint256 tokenId,
        uint256 amount,
        address currency,
        uint256 price,
        uint256 timestamp,
        address seller,
        address buyer
    );

    struct MakeOfferRequest {
        uint256 id;
        uint256 nftType;
        address nft;
        uint256 tokenId;
        uint256 amount;
        address currency;
        uint256 price;
        uint duration;
    }

    struct Offer {
        uint256 id;
        uint256 nftType;
        address nft;
        uint256 tokenId;
        uint256 amount;
        address currency;
        uint256 price;
        uint256 duration;
        address offerer;
        uint256 timestamp;
    }

    event MakeOfferEvent(
        uint256 id,
        uint256 nftType,
        address nft,
        uint256 tokenId,
        uint256 amount,
        address currency,
        uint256 price,
        address offerAddress,
        uint256 startedAt,
        uint256 duration
    );

    event AcceptOfferEvent(uint256 id, address acceptor, uint256 timestamp);

    event CancelOfferEvent(uint256 id, uint256 timestamp);

    function buy(ListRequest memory request, uint256 buyAmount) external payable;

    function batchBuy(ListRequest[] memory requests, uint256[] memory buyAmounts) external payable;

    function makeOffer(MakeOfferRequest memory request) external payable;

    function batchMakeOffer(MakeOfferRequest[] memory requests) external payable;

    function cancelOffer(uint256 offerId) external;

    function batchCancelOffer(uint256[] memory offerIds) external;

    function acceptOffer(uint256 offerId) external;

    function batchAcceptOffer(uint256[] memory offerIds) external;

    function transfer(TransferRequest memory request) external;

    function batchTransfer(TransferRequest[] memory requests) external;

    function queryMarketFeeConfig() external view returns (FeeConfig memory config);

    function queryDefaultRoyaltyFeeConfig() external view returns (FeeConfig memory config);

    function queryRoyaltyFeeConfig(address nft) external view returns (FeeConfig memory config);
}
