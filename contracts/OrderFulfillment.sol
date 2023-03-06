// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ICloudaxShared.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// ================================
// CUSTOM ERRORS
// ================================
error QuantityRequired(uint256 supply, uint256 minRequired);
error InvalidAddress();
error InvalidItemId(uint256 itemId);
error ItemSoldOut(uint256 supply, uint256 numSold);
error NotEnoughNft(uint256 supply, uint256 numSold, uint256 purchaseQuantityRequest);
error InsufficientFund(uint256 price, uint256 allowedFund);

contract OrderFulfillment is
    ReentrancyGuard,
    Ownable 
{
    using SafeMath for uint256;

    uint256 internal _currentOfferIndex;

    // Made public for test purposes
    ICloudaxShared public cloudaxShared;
    

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

    struct Collection{
        address payable fundingRecipient;
        uint256 creatorFee;
        address owner;
    }

    // structs for an item to be listed
    struct ListedItem {
        address nftAddress;
        uint256 numSold;
        uint256 royaltyBPS;
        address payable fundingRecipient;
        uint256 supply; 
        uint256 price;
        uint256 itemId;
        uint256 collectionId;   
    }

    mapping(uint256 => OfferOrder) internal _idToOfferOrder;
    //Mapping of items to a SoldItem struct

    //Mapping of collectionId to a collection struct
    mapping(uint256 => Collection) public s_collection;

    mapping(address => mapping(uint256 => ListedItem)) public s_listedItems;


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

    event SharedInterfaceChanged(ICloudaxShared oldAddress, address newAddress);

    constructor(address _cloudaxShared) 
    {
        cloudaxShared = ICloudaxShared(_cloudaxShared);
    }

    modifier isValidated(address fundingRecipient,uint256 supply){
        if (fundingRecipient == address(0)) {
            revert InvalidAddress();
        }
        // Check that the track's supply is more than zero(0).
        if (supply <= 0) {
            revert QuantityRequired({supply: supply, minRequired: 1});
        }
        _;
    }

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

    function setShared(address newAddress) external onlyOwner {
        emit SharedInterfaceChanged(cloudaxShared, newAddress);
        cloudaxShared = ICloudaxShared(newAddress);
    }

    function fulfillOfferOrder(
        address payable fundingR,
        uint256 collectionId,
        string memory itemId,
        string memory _tokenUri,
        uint256 _qty,
        uint256 _supply,
        uint256 offerCount,
        uint256 offerPrice,
        address winnigOfferAddress
    ) external payable nonReentrant isValidated(fundingR, _supply) {
        require(_qty >= 1, "Must buy atleast one nft");
        require(
            collectionId <= cloudaxShared.nextCollectionId(address(cloudaxShared)),
            "Collection does not exist"
        );
          Collection memory collection = s_collection[collectionId];
        // if (tokenId == 0){
            ListedItem memory listings = s_listedItems[address(this)][
                cloudaxShared.getItemId(itemId)
            ];
            // uint256 supply = listings.supply;
            if (
                listings.itemId != cloudaxShared.nextItemId() ||
                listings.supply == 0 ||
                cloudaxShared.nextItemId() == 0
            ) {
                address fAddress = fundingR;
                cloudaxShared.createItem(
                    collectionId,
                    itemId,
                    payable(fAddress),
                    offerPrice,
                    _supply
                );
            }

            // uint256 itemID = nextItemId();
            ListedItem memory listing = s_listedItems[address(this)][cloudaxShared.nextItemId()];
          

            // Check that the item's ID is not Zero(0).
            if (cloudaxShared.nextItemId() <= 0) {
                revert InvalidItemId({itemId: cloudaxShared.nextItemId()});
            }
            // Check that there are still some copies or tokens of the item that are available for purchase.
            if (listing.supply <= listing.numSold) {
                // s_idToItemStatus[nextItemId()] = TokenStatus.SOLDOUT;
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
            s_listedItems[address(this)][cloudaxShared.nextItemId()] = listing;
        
            // https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]/[TOKEN_ID]
            // Where _tokenBaseURI = https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
            // Generating a metadata URL for the new copy of the ITEM or Token that was generated.

            cloudaxShared.getERC20Token().transferFrom(winnigOfferAddress, address(this), offerPrice);

            //Deduct the service fee
            uint256 serviceFee = msg.value.mul(cloudaxShared.getServiceFee()).div(100); // no msg.value
            uint256 royalty = msg.value.mul(collection.creatorFee).div(100);
            uint256 finalAmount = msg.value.sub(serviceFee.add(royalty));

            // Adding the newly earned money to the total amount a user has earned from an Item.
            // s_depositedForItem[nextItemId()] += finalAmount; // optmize
            cloudaxShared.addPlatformEarning(serviceFee);
            cloudaxShared.setIndivivdualEarningInPlatform(listings.fundingRecipient, finalAmount);
            cloudaxShared.setIndivivdualEarningInPlatform(collection.fundingRecipient, royalty);
            cloudaxShared.addTotalAmount(msg.value);

            cloudaxShared.getERC20Token().transfer(listings.fundingRecipient, finalAmount);
            cloudaxShared.getERC20Token().transfer(collection.fundingRecipient, royalty);

            string memory uri = _tokenUri;
            uint256 qty = _qty;

            // Mint a new copy or token from the Item for the buyer
            cloudaxShared.safeMintOut(qty, uri, cloudaxShared.nextItemId(), winnigOfferAddress);
            // s_idToItemStatus[_nextTokenId()] = TokenStatus.ACTIVE;

            _idToOfferOrder[_nextOfferId()] = OfferOrder({
                index: _nextOfferId(),
                nftAddress: address(this),
                addressPaymentToken: address(cloudaxShared.getERC20Token()),
                tokenIdFrom: cloudaxShared.getItemsSold(),
                quantity: qty,
                itemId: cloudaxShared.nextItemId(),
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
                address(cloudaxShared.getERC20Token()),
                cloudaxShared.getItemsSold(),
                qty,
                cloudaxShared.getItemsCreated(),
                receiver,
                collection.fundingRecipient,
                offerP,
                offerC
            );
        
    }

     function listItem
    (
        address nftAddress,
        uint256 numSold,
        uint256 royaltyBPS,
        address payable fundingRecipient,
        uint256 supply,
        uint256 price,
        uint256 itemId,
        uint256 collectionId,
        address mappingAddress,
        uint256 mappingId
    ) public
        {
            s_listedItems[mappingAddress][mappingId] = ListedItem({
                nftAddress: nftAddress,
                numSold: numSold,
                royaltyBPS: royaltyBPS,
                fundingRecipient: fundingRecipient,
                supply: supply,
                price: price,
                itemId: itemId,
                collectionId: collectionId
            });
        }

}
 