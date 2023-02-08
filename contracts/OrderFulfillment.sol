// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./CloudaxMarketplace.sol";

contract OrderFulfillment is CloudaxMarketplace {
    // https://cloudaxnftmarketplace.xyz/metadata/

    using SafeMath for uint256;

    // Structure to define "make an offer" properties
    struct OfferOrder {
        uint256 index; // Offer Index
        address nftAddress; // Address of the ERC721 NFT Collection contract
        address addressPaymentToken; // Address of the ERC20 Payment Token contract
        uint256 tokenIdFrom; // NFT Id
        uint256 quantity; // NFT Id
        uint256 itemId; // NFT Id
        address creator; // Creator of the item
        address payable winnigOfferAddress; // Address of the winning bider
        uint256 offerPrice; // Current offer of the offer
        uint256 offerCount; // Number of offers placed on the item
    }

    mapping(uint256 => OfferOrder) internal _idToOfferOrder;

    event OfferFulfilled(
        uint256 indexed index, // Offer Index
        address indexed nftAddress, // Address of the ERC721 NFT Collection contract
        address addressPaymentToken, // Address of the ERC20 Payment Token contract
        uint256 tokenIdFrom, // NFT Id
        uint256 quantity, // NFT Id
        uint256 itemId, // NFT Id
        address creator, // Creator of the item
        address indexed winnigOfferAddress, // Address of the winning bider
        uint256 offerPrice, // Current offer of the offer
        uint256 offerCount // Number of offers placed on the item
    );

    constructor() {}

    /**
     * @dev Returns the starting offer ID.
     * To change the starting offer ID, please override this function.
     */
    function _startOfferId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the next offer ID to be minted.
     */
    function _nextOfferId() internal view virtual returns (uint256) {
        return _currentOfferIndex;
    }

    function fulfillOfferOrder(
        address payable _fundingRecipient,
        uint256 collectionId,
        string memory itemId,
        string memory _tokenUri,
        uint256 _qty,
        uint256 _supply,
        uint256 offerCount,
        uint256 offerPrice,
        address winnigOfferAddress
    ) public nonReentrant isValidated(_fundingRecipient, _supply) {
        require(_qty >= 1, "Must buy atleast one nft");

        require(
            collectionId <= _nextCollectionId(),
            "Collection does not exist"
        );

        ListedItem memory listings = s_listedItems[address(this)][
            s_itemIdDBToItemId[itemId]
        ];
        // uint256 supply = listings.supply;
        if (
            listings.itemId != _nextItemId() ||
            listings.supply == 0 ||
            _nextItemId() == 0
        ) {
            _createItem(
                collectionId,
                itemId,
                _fundingRecipient,
                offerPrice,
                _supply
            );
        }

        // uint256 itemID = _nextItemId();
        ListedItem memory listing = s_listedItems[address(this)][_nextItemId()];
        Collection memory collection = s_collection[collectionId];
        // Check that the item's ID is not Zero(0).
        if (_nextItemId() <= 0) {
            revert InvalidItemId({itemId: _nextItemId()});
        }
        // Check that there are still some copies or tokens of the item that are available for purchase.
        if (listing.supply <= listing.numSold) {
            s_idToItemStatus[_nextItemId()] = TokenStatus.SOLDOUT;
            revert ItemSoldOut({
                supply: listing.supply,
                numSold: listing.numSold
            });
        }
        // Check that there will be enough copies or tokens of the item to fulfil purchase order.
        if (listing.numSold.add(_qty) > listing.supply) {
            revert NotEnoughNft({
                supply: listing.supply,
                numSold: listing.numSold,
                purchaseQuantityRequest: _qty
            });
        }
        // Check that the buyer approved an amount that is equal or more than the price of the item set by the seller.
        if (listing.price > offerPrice) {
            revert InsufficientFund({
                price: listing.price,
                allowedFund: offerPrice
            });
        }

        // Increment the number of copies or tokens sold from this Item.
        listing.numSold = listing.numSold + _qty;
        s_listedItems[address(this)][_nextItemId()] = listing;

        // https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]/[TOKEN_ID]
        // Where _tokenBaseURI = https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
        // Generating a metadata URL for the new copy of the ITEM or Token that was generated.

        if (
            ERC20Token.transferFrom(
                winnigOfferAddress,
                address(this),
                offerPrice.mul(_qty)
            ) == !true
        ) {
            revert TransferNotCompleted({
                senderBalance: ERC20Token.balanceOf(winnigOfferAddress),
                fundTosend: offerPrice
            });
        }

        //Deduct the service fee
        uint256 serviceFee = offerPrice.mul(_qty).mul(SERVICE_FEE).div(100);
        uint256 royalty = offerPrice.mul(collection.creatorFee).div(100);
        uint256 finalAmount = offerPrice.mul(_qty).sub(
            serviceFee.add(royalty.mul(_qty))
        );

        // Adding the newly earned money to the total amount a user has earned from an Item.
        s_depositedForItem[_nextItemId()] += finalAmount; // optmize
        s_platformEarning += serviceFee;
        s_indivivdualEarningInPlatform[
            listings.fundingRecipient
        ] += finalAmount;
        s_indivivdualEarningInPlatform[collection.fundingRecipient] += royalty
            .mul(_qty);
        s_totalAmount += offerPrice.mul(_qty);

        // Send funds to the funding recipient.
        // Set ERC20 token to wETH address or any other preferred currency
        if (
            ERC20Token.transferFrom(
                address(this),
                listings.fundingRecipient,
                finalAmount
            ) == !true
        ) {
            revert TransferNotCompleted({
                senderBalance: ERC20Token.balanceOf(address(this)),
                fundTosend: finalAmount
            });
        }

        if (
            ERC20Token.transferFrom(
                address(this),
                collection.fundingRecipient,
                royalty
            ) == !true
        ) {
            revert TransferNotCompleted({
                senderBalance: ERC20Token.balanceOf(address(this)),
                fundTosend: royalty.mul(_qty)
            });
        }

        string memory uri = _tokenUri;
        uint256 qty = _qty;

        // Mint a new copy or token from the Item for the buyer
        safeMintOut(_qty, uri, _nextItemId(), winnigOfferAddress);
        s_idToItemStatus[_nextTokenId()] = TokenStatus.ACTIVE;

        _idToOfferOrder[_nextOfferId()] = OfferOrder({
            index: _nextOfferId(),
            nftAddress: address(this),
            addressPaymentToken: address(ERC20Token),
            tokenIdFrom: _nextTokenId(),
            quantity: qty,
            itemId: _nextItemId(),
            winnigOfferAddress: payable(winnigOfferAddress),
            creator: collection.fundingRecipient,
            offerPrice: offerPrice,
            offerCount: offerCount
        });

        s_soldItems[address(this)][_nextTokenId()] = SoldItem({
            nftAddress: address(this),
            tokenIdFrom: _nextTokenId(),
            quantity: qty,
            itemId: _nextItemId(),
            buyer: payable(winnigOfferAddress),
            creator: collection.fundingRecipient,
            itemBaseURI: uri,
            amountEarned: finalAmount
        });

        uint256 offerC = offerCount;
        uint256 offerP = offerPrice;
        address receiver = payable(winnigOfferAddress);

        emit OfferFulfilled(
            _nextOfferId(),
            address(this),
            address(ERC20Token),
            _nextTokenId(),
            qty,
            _currentItemIndex,
            receiver,
            collection.fundingRecipient,
            offerP,
            offerC
        );
    }
}
