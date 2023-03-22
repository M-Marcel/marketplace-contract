// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
// pragma solidity >=0.8.4 <0.9.0;

import "./CloudaxMarketplace.sol";

contract OrderFulfillment is CloudaxMarketplace {
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

    function fulfillOfferOrderResell
    (
        address payable _fundingRecipient,
        uint256 offerPrice,
        address winnigOfferAddress,
        address nftAddress,
        uint256 tokenId
    ) public
    {
        
        require(
            _fundingRecipient == msg.sender,
            "Only the nft owner can receive payment for nft"
        );
        if (offerPrice <= 0) {
            revert PriceMustBeAboveZero();
        }

        ERC20Token.transferFrom(winnigOfferAddress, address(this), offerPrice);

        //Deduct the service fee
        uint256 serviceFee = offerPrice.mul(SERVICE_FEE).div(100);
        uint256 finalAmount = offerPrice.sub(serviceFee);

        // Send funds to the funding recipient.
        ERC20Token.transfer(
            _fundingRecipient,
            finalAmount
        );

        s_platformEarning += serviceFee;
        s_indivivdualEarningInPlatform[
            _fundingRecipient
        ] += finalAmount;
    
        s_totalAmount += offerPrice;

        IERC721A(nftAddress).safeTransferFrom(_fundingRecipient, winnigOfferAddress, tokenId);

    }

    function fulfillOfferOrder 
    (
        address payable _fundingRecipient,
        string memory itemId,
        string memory _tokenUri,
        uint256 _price,
        uint256 _qty,
        uint256 _supply,
        address payable royaltyAddress,
        uint256 royaltyFee,
        uint256 offerPrice,
        address winnigOfferAddress
    ) public
    {
        
        ListedItem memory listings = s_listedItems[address(this)][s_itemIdDBToItemId[itemId]];
        if (listings.itemId != nextItemId() || listings.supply == 0 || nextItemId() == 0 )  {
            _createItem(
                itemId,
                _fundingRecipient,
                _price,
                _supply,
                royaltyAddress,
                royaltyFee
            );
        }
    
        ListedItem memory listing = s_listedItems[address(this)][nextItemId()];

        // Validations
        if (listing.supply <= 0) {
            revert SupplyDoesNotExist({availableSupply: listing.supply});
        }
        // Check that the item's ID is not Zero(0).
        if (nextItemId() <= 0) {
            revert InvalidItemId({itemId: nextItemId()});
        }
        // Check that there are still some copies or tokens of the item that are available for purchase.
        if (listing.supply <= listing.numSold) {
            revert ItemSoldOut({supply: listing.supply, numSold: listing.numSold});
        }
        // Check that there will be enough copies or tokens of the item to fulfil purchase order.
        if (listing.numSold.add(_qty) > listing.supply) {
            revert NotEnoughNft({supply: listing.supply, numSold: listing.numSold, purchaseQuantityRequest: _qty});
        }
        // Check that the buyer approved an amount that is equal or more than the price of the item set by the seller.
        if (listing.price.mul(_qty) != offerPrice.mul(_qty)) {
            revert InsufficientFund({price: listing.price.mul(_qty), allowedFund: offerPrice.mul(_qty)});
        }

        // Increment the number of copies or tokens sold from this Item.
        listing.numSold = listing.numSold + _qty;

        s_listedItems[address(this)][nextItemId()] = listing;

        ERC20Token.transferFrom(winnigOfferAddress, address(this), offerPrice);

        //Deduct the service fee
        uint256 serviceFee = offerPrice.mul(SERVICE_FEE).div(100);
        uint256 royalty = offerPrice.mul(listing.royaltyBPS).div(100);
        uint256 finalAmount = offerPrice.sub(serviceFee.add(royalty));

        // Send funds to the funding recipient.
        ERC20Token.transfer(
            listing.fundingRecipient,
            finalAmount
        );
        if (royalty != 0){
            ERC20Token.transfer(
            listing.royaltyAddress,
            royalty
            );
        }

        s_platformEarning += serviceFee;
        s_indivivdualEarningInPlatform[
            listing.fundingRecipient
        ] += finalAmount;
        s_indivivdualEarningInPlatform[listing.royaltyAddress] += royalty;
        s_totalAmount += offerPrice;

        safeMintOut(_qty, _tokenUri, winnigOfferAddress);

    }

}

    