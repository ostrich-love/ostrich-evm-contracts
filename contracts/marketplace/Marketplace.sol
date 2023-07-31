// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IMarketplace.sol";
import "../common/SafeAccess.sol";
import "../common/ERC721Transferer.sol";
import "../common/ERC1155Transferer.sol";
import "../common/TokenTransferer.sol";

contract Marketplace is
    ReentrancyGuard,
    Pausable,
    Ownable,
    SafeAccess,
    ERC721Transferer,
    TokenTransferer,
    ERC1155Transferer,
    IMarketplace
{
    bytes32 public constant DOMAIN_TYPE_HASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    bytes32 public constant LIST_TYPE_HASH =
        keccak256(
            "list(uint256 id,uint256 nftType,address nft,uint256 tokenId,uint256 amount,address currency,uint256 price,uint256 deadline,address seller)"
        );

    bytes32 private _domainSeparator;

    mapping(uint256 => uint256) private _requestIdSalesAmounts;

    mapping(uint256 => Offer) private _offers;
    mapping(address => FeeConfig) private _royaltyFeeConfigs;

    FeeConfig private _marketFeeConfig;
    FeeConfig private _defaultRoyaltyFeeConfig;

    constructor() Ownable() ReentrancyGuard() Pausable() {
        _domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPE_HASH, keccak256(bytes("OstrichMarketplace")), _getChainId(), address(this))
        );
    }


    function updateMarketFeeConfig(uint256 rate, address receiver) public onlyOwner {
        _marketFeeConfig.rate = rate;
        _marketFeeConfig.receiver = receiver;
    }

    function updateDefaultRoyaltyFeeConfig(uint256 rate, address receiver) public onlyOwner {
        _defaultRoyaltyFeeConfig.rate = rate;
        _defaultRoyaltyFeeConfig.receiver = receiver;
    }

    function updateRoyaltyFeeConfig(address nft, uint256 rate, address receiver) public onlyOwner {
        _royaltyFeeConfigs[nft] = FeeConfig({ rate: rate, receiver: receiver });
    }

    function queryMarketFeeConfig() public view override returns (FeeConfig memory config) {
        config = _marketFeeConfig;
    }

    function queryDefaultRoyaltyFeeConfig() public view override returns (FeeConfig memory config) {
        config = _defaultRoyaltyFeeConfig;
    }

    function queryRoyaltyFeeConfig(address nft) public view override returns (FeeConfig memory config) {
        config = _royaltyFeeConfigs[nft];
        if (config.rate == 0 || config.receiver == address(0)) {
            config = _defaultRoyaltyFeeConfig;
        }
    }

    function buy(
        ListRequest memory request,
        uint256 buyAmount
    ) external payable override nonReentrant isNotContractCall whenNotPaused {
        _innerBuy(request, buyAmount);
    }

    function batchBuy(
        ListRequest[] memory requests,
        uint256[] memory buyAmounts
    ) external payable override nonReentrant isNotContractCall whenNotPaused {
        for (uint256 i = 0; i < requests.length; i++) {
            _innerBuy(requests[i], buyAmounts[i]);
        }
    }

    function querySalesAmounts(uint256 requestId) public view returns (uint256) {
        return _requestIdSalesAmounts[requestId];
    }

    function _innerBuy(ListRequest memory request, uint256 buyAmount) private {
        require(_requestIdSalesAmounts[request.id] + buyAmount <= request.amount, "EXCEED_MAX_LIST_AMOUNT");
        _requestIdSalesAmounts[request.id] += buyAmount;
        _verifySignature(request);
        _buy(request, buyAmount);
    }

    function makeOffer(
        MakeOfferRequest memory order
    ) external payable override nonReentrant isNotContractCall whenNotPaused {
        _makeOffer(order);
    }

    function batchMakeOffer(
        MakeOfferRequest[] memory orders
    ) external payable override nonReentrant isNotContractCall whenNotPaused {
        for (uint256 i = 0; i < orders.length; i++) {
            _makeOffer(orders[i]);
        }
    }

    function _makeOffer(MakeOfferRequest memory request) private {
        address sender = msg.sender;
        require(_offers[request.id].id == 0, "DUPLICATE_OFFER_ID");
        require(request.price > 0, "INVALID_PRICE");
        uint256 totalPayment = request.price * request.amount;
        transferTokenFrom(request.currency, sender, totalPayment);
        Offer memory offer = Offer({
            id: request.id,
            nftType: request.nftType,
            nft: request.nft,
            tokenId: request.tokenId,
            amount: request.amount,
            currency: request.currency,
            price: request.price,
            duration: request.duration,
            offerer: sender,
            timestamp: _getTimestamp()
        });

        _offers[request.id] = offer;
        emit MakeOfferEvent(
            offer.id,
            request.nftType,
            request.nft,
            request.tokenId,
            request.amount,
            request.currency,
            request.price,
            sender,
            offer.timestamp,
            offer.duration
        );
    }

    function cancelOffer(uint256 offerId) external override nonReentrant whenNotPaused isNotContractCall {
        _cancelOffer(offerId);
    }

    function batchCancelOffer(
        uint256[] memory offerIds
    ) external override nonReentrant whenNotPaused isNotContractCall {
        for (uint256 i = 0; i < offerIds.length; i++) {
            _cancelOffer(offerIds[i]);
        }
    }

    function acceptOffer(uint256 offerId) external override nonReentrant whenNotPaused isNotContractCall {
        _acceptOffer(offerId);
    }

    function batchAcceptOffer(
        uint256[] memory offerIds
    ) external override nonReentrant whenNotPaused isNotContractCall {
        for (uint256 i = 0; i < offerIds.length; i++) {
            _acceptOffer(offerIds[i]);
        }
    }

    function _acceptOffer(uint256 offerId) private {
        address sender = msg.sender;
        Offer memory offer = _offers[offerId];
        require(offer.id != 0, "OFFER_NOT_EXISTS");
        require(offer.timestamp + offer.duration > _getTimestamp(), "EXPIRED");
        delete _offers[offerId];
        if (offer.nftType == 1155) {
            transferERC1155(offer.nft, sender, offer.offerer, offer.tokenId, offer.amount);
        } else {
            transferERC721(offer.nft, sender, offer.offerer, offer.tokenId);
        }
        uint256 totalPayment = offer.price * offer.amount;
        uint totalFee = _chargeFee(offer.nft, offer.currency, totalPayment);
        transferTokenTo(offer.currency, sender, totalPayment - totalFee);
        emit AcceptOfferEvent(offer.id, sender, _getTimestamp());
    }

    function transfer(TransferRequest memory request) public override {
        if (request.nftType == 721) {
            transferERC721(request.nft, msg.sender, request.to, request.tokenId);
        } else {
            transferERC1155(request.nft, msg.sender, request.to, request.tokenId, request.amount);
        }
    }

    function batchTransfer(TransferRequest[] memory requests) external override {
        for (uint256 i; i < requests.length; i++) {
            transfer(requests[i]);
        }
    }

    function _verifySignature(ListRequest memory req) private view {
        require(req.deadline >= block.timestamp, "EXPIRED");
        require(req.seller != address(0), "INVALID_SELLER");
        bytes32 listHash = keccak256(
            abi.encode(
                LIST_TYPE_HASH,
                req.id,
                req.nftType,
                req.nft,
                req.tokenId,
                req.amount,
                req.currency,
                req.price,
                req.deadline,
                req.seller
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, listHash));
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(req.signature);
        require(ecrecover(digest, v, r, s) == req.seller, "INVALID_EIP712_SIGNATURE");
    }

    function _splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function _buy(ListRequest memory req, uint256 buyAmount) private {
        address buyer = msg.sender;
        uint256 totalPayment = req.price * buyAmount;
        transferTokenFrom(req.currency, buyer, totalPayment);
        if (req.nftType == 1155) {
            transferERC1155(req.nft, req.seller, buyer, req.tokenId, buyAmount);
        } else {
            transferERC721(req.nft, req.seller, buyer, req.tokenId);
        }
        uint totalFee = _chargeFee(req.nft, req.currency, totalPayment);
        transferTokenTo(req.currency, req.seller, totalPayment - totalFee);
        emit BuyEvent(
            req.id,
            req.nftType,
            req.nft,
            req.tokenId,
            buyAmount,
            req.currency,
            req.price,
            _getTimestamp(),
            req.seller,
            buyer
        );
    }

    function _cancelOffer(uint256 offerId) private {
        address sender = msg.sender;
        Offer memory offer = _offers[offerId];
        require(offer.offerer == sender, "INVALID_CALL");
        delete _offers[offerId];
        transferTokenTo(offer.currency, sender, offer.price);
        emit CancelOfferEvent(offer.id, _getTimestamp());
    }

    function _chargeFee(address nft, address currency, uint256 totalPayment) private returns (uint256 totalFee) {
        FeeConfig memory config = queryMarketFeeConfig();
        uint256 marketFee = (totalPayment * config.rate) / 10000;
        if (marketFee > 0 && config.receiver != address(0)) {
            transferTokenTo(currency, config.receiver, marketFee);
            totalFee += marketFee;
        }
        config = queryRoyaltyFeeConfig(nft);
        uint256 royaltyFee = (totalPayment * config.rate) / 10000;
        if (royaltyFee > 0 && config.receiver != address(0)) {
            transferTokenTo(currency, config.receiver, royaltyFee);
            totalFee += royaltyFee;
        }
    }

    function _getTimestamp() private view returns (uint) {
        return block.timestamp;
    }

    function _getChainId() private view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    function emergencyWithdraw(address token, address to, uint256 amount) public onlyOwner {
        transferTokenTo(token, to, amount);
    }
}
