// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
// pragma solidity >=0.8.4 <0.9.0;

import "./CloudaxShared.sol";
import "./interfaces/IOrderFulfillment.sol";

contract OrderFulfillment is 
CloudaxShared,
IOrderFulfillment 
{
    using SafeMath for uint256;

    uint256 internal _currentOfferIndex;

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
    //Mapping of items to a SoldItem struct


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
        // address nftAddress,
        // uint256 tokenId
    ) external payable nonReentrant isValidated(_fundingRecipient, _supply) {
        // uint256 id = s_itemIdDBToItemId[itemId];
        require(_qty >= 1, "Must buy atleast one nft");
        require(
            collectionId <= _nextCollectionId(),
            "Collection does not exist"
        );
          Collection memory collection = s_collection[collectionId];
        // if (tokenId == 0){
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
          

            // Check that the item's ID is not Zero(0).
            if (_nextItemId() <= 0) {
                revert InvalidItemId({itemId: _nextItemId()});
            }
            // Check that there are still some copies or tokens of the item that are available for purchase.
            if (listing.supply <= listing.numSold) {
                // s_idToItemStatus[_nextItemId()] = TokenStatus.SOLDOUT;
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
            if (listing.price > msg.value) {
                revert InsufficientFund({
                    price: listing.price,
                    allowedFund: msg.value
                });
            }

            // Increment the number of copies or tokens sold from this Item.
            listing.numSold = listing.numSold + _qty;
            s_listedItems[address(this)][_nextItemId()] = listing;
        
            // https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]/[TOKEN_ID]
            // Where _tokenBaseURI = https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
            // Generating a metadata URL for the new copy of the ITEM or Token that was generated.

            ERC20Token.transferFrom(winnigOfferAddress, address(this), offerPrice);

            //Deduct the service fee
            uint256 serviceFee = msg.value.mul(SERVICE_FEE).div(100);
            uint256 royalty = msg.value.mul(collection.creatorFee).div(100);
            uint256 finalAmount = msg.value.sub(serviceFee.add(royalty));

            // Adding the newly earned money to the total amount a user has earned from an Item.
            // s_depositedForItem[_nextItemId()] += finalAmount; // optmize
            s_platformEarning += serviceFee;
            s_indivivdualEarningInPlatform[
                listings.fundingRecipient
            ] += finalAmount;
            s_indivivdualEarningInPlatform[collection.fundingRecipient] += royalty;
            s_totalAmount += msg.value;

            // Send funds to the funding recipient.
            ERC20Token.transferFrom(
                address(this),
                listings.fundingRecipient,
                finalAmount
            );
            ERC20Token.transferFrom(
                address(this),
                collection.fundingRecipient,
                royalty
            );

            string memory uri = _tokenUri;
            uint256 qty = _qty;

            // Mint a new copy or token from the Item for the buyer
            safeMint(_qty, uri, _nextItemId());
            // s_idToItemStatus[_nextTokenId()] = TokenStatus.ACTIVE;

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
            
        // }
        // else{
        //     ListedToken memory listing = s_listedTokens[nftAddress][tokenId];
        //     s_listedTokens[nftAddress][tokenId] = ListedToken(
        //        nftAddress,
        //         collection.creatorFee,
        //         collection.fundingRecipient,
        //         offerPrice,
        //         collection.fundingRecipient,
        //         0,
        //         tokenId,
        //         collectionId
        //     ); 
        // }
        // s_soldItems[address(this)][_nextTokenId()] = SoldItem({
        //     nftAddress: address(this),
        //     tokenIdFrom: _nextTokenId(),
        //     quantity: qty,
        //     itemId: _nextItemId(),
        //     buyer: payable(winnigOfferAddress),
        //     creator: collection.fundingRecipient,
        //     itemBaseURI: uri,
        //     amountEarned: finalAmount
        // });

        

        
    }

    // function fulfillOfferOrderResell(
    //     address payable _fundingRecipient,
    //     address nftItemAddress,
    //     uint256 collectionId,
    //     uint256 tokenId,
    //     uint256 _supply,
    //     uint256 offerCount,
    //     uint256 offerPrice,
    //     address winnigOfferAddress
    // ) public payable nonReentrant isOwner(nftItemAddress, tokenId, msg.sender) {

    //     require(
    //         collectionId <= _nextCollectionId(),
    //         "Collection does not exist"
    //     );
    //     require(
    //         _fundingRecipient == msg.sender,
    //         "Only the nft owner can receive payment for nft"
    //     );
    //     if (offerPrice <= 0) {
    //         revert PriceMustBeAboveZero();
    //     }

    //     ListedToken memory listing = s_listedTokens[nftItemAddress][tokenId];
    //     Collection memory collection = s_collection[collectionId];

    //     uint256 serviceFee = msg.value.mul(SERVICE_FEE).div(100);
    //     // uint256 fundingR = _fundingRecipient;
    //     // uint256 colId = collectionId;
    //     address nftAd = nftItemAddress;
    //     // address thisAd = address(this);
    //     // uint256 tID = tokenId;

    //     if (nftAd == address(this)){
    //         s_listedTokens[nftItemAddress][tokenId] = ListedToken(
    //            nftAd,
    //             collection.creatorFee,
    //             collection.fundingRecipient,
    //             offerPrice,
    //             collection.fundingRecipient,
    //             0,
    //             tokenId,
    //             collectionId
    //         ); 

    //             emit TokenListed
    //         (
    //             nftItemAddress,
    //             tokenId,
    //             0,
    //             msg.sender,
    //             offerPrice,
    //             collection.fundingRecipient,
    //             collection.creatorFee,
    //             block.timestamp,
    //             collectionId
    //         );

    //         //Deduct the service fee
    //         // uint256 serviceFee = msg.value.mul(SERVICE_FEE).div(100);
    //         uint256 royalty = msg.value.mul(listing.royaltyBPS).div(100);
    //         uint256 finalAmount = msg.value.sub(serviceFee.add(royalty));

    //         // Adding the newly earned money to the total amount a user has earned from an Item.
    //         // s_depositedForItem[_nextItemId()] += finalAmount; // optm
    //         s_platformEarning += serviceFee;
    //         s_indivivdualEarningInPlatform[listing.creator] += finalAmount;
    //         s_totalAmount += msg.value;

    //         // Send funds to the funding recipient.
    //         ERC20Token.transferFrom(address(this), listing.fundingRecipient, finalAmount);
    //         ERC20Token.transferFrom(address(this), collection.fundingRecipient, royalty);
    //     }

    //     s_listedTokens[nftItemAddress][tokenId] = ListedToken(
    //         nftItemAddress,
    //         0,
    //         _fundingRecipient,
    //         offerPrice,
    //         address(0),
    //         0,
    //         tokenId,
    //         0
    //     );

    //        //     address nftAddress;
    //     // uint256 royaltyBPS;
    //     // address payable fundingRecipient;
    //     // uint256 price;
    //     // address creator;
    //     // uint256 itemId;
    //     // uint256 tokenId; 
    //     // uint256 collectionId; 

    //     // s_idToItemStatus[tokenId] = TokenStatus.ONSELL;

    //     emit TokenListed
    //     (
    //         nftItemAddress,
    //         tokenId,
    //         0,
    //         msg.sender,
    //         offerPrice,
    //         address(0),
    //         0,
    //         block.timestamp,
    //         0
    //     );

    //     uint256 finalAmount = msg.value.sub(serviceFee);

    //     // Update the deposited total for the item.
    //     // Adding the newly earned money to the total amount a user has earned from an Item.
    //     // s_depositedForItem[tokenId] += finalAmount;
    //     s_indivivdualEarningInPlatform[
    //         listing.creator
    //     ] += finalAmount;
    //     s_platformEarning += serviceFee;
    //     s_totalAmount += msg.value;

    //     // Send funds to the funding recipient.
    //     ERC20Token.transferFrom(address(this), listing.fundingRecipient, finalAmount);

    //     // transfer nft to buyer
    //     IERC721A(nftItemAddress).safeTransferFrom(listing.creator, msg.sender, tokenId);

    //     // s_idToItemStatus[tokenId] = TokenStatus.ACTIVE;

    //     emit NftSold(
    //         nftItemAddress,
    //         tokenId,
    //         0,
    //         msg.sender,
    //         listing.creator,
    //         "",
    //         finalAmount,
    //         block.timestamp
    //     );

    // }
}
 