// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "./interfaces/ICloudaxShared.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

////Custom Errors
error NoProceeds();
error SupplyDoesNotExist(uint256 availableSupply);
error NotListed(uint256 tokenId);
error InvalidItemId(uint256 itemId);
error QuantityRequired(uint256 supply, uint256 minRequired);
error InvalidAddress();
error NotOwner();
error ItemSoldOut(uint256 supply, uint256 numSold);
error NotEnoughNft(uint256 supply, uint256 numSold, uint256 purchaseQuantityRequest);
error InsufficientFund(uint256 price, uint256 allowedFund);
error PriceMustBeAboveZero();
error TransferFailed();

//000000000000000000
//www.cloudax.com/meta


contract CloudaxMarketplace is
    ReentrancyGuard,
    Ownable
{
    using SafeMath for uint256;

// -----------------------------------VARIABLES-----------------------------------
    
    string internal s_contractBaseURI;

    // Made public for test purposes
    ICloudaxShared public cloudaxShared;

    struct SoldItem {
        address nftAddress;
        uint256 amountEarned;
        address payable buyer;
        string itemBaseURI;
        address payable creator;
        uint256 tokenIdFrom;
        uint256 quantity;
        uint256 itemId;      
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

    // structs for an item to be listed
    struct ListedToken {
        address nftAddress;
        uint256 royaltyBPS;
        address payable fundingRecipient;
        uint256 price;
        address creator;
        uint256 itemId;
        uint256 tokenId; 
        uint256 collectionId;  
    }

    struct Collection{
        address payable fundingRecipient;
        uint256 creatorFee;
        address owner;
    }

    mapping(address => mapping(uint256 => SoldItem)) public s_soldItems;

    mapping(address => mapping(uint256 => ListedItem)) public s_listedItems;

    //Mapping of items to a ListedItem struct
    mapping(address => mapping(uint256 => ListedToken)) public s_listedTokens;

    //Mapping of collectionId to a collection struct
    mapping(uint256 => Collection) public s_collection;

    // ================================
    // EVENTS
    // ================================
    

    //Emitted when a copy of an item is sold
    event ItemCopySold(
        uint256 indexed startItemCopyId,
        uint256 quantity, 
        address indexed seller,
        address indexed buyer,
        uint256 amountEarned,
        uint256 numSold
    );

    event ItemCopySold1(
        string indexed soldItemIdDB,
        string soldItemBaseURI
    );

    ///Emitted when a copy of an item is sold
    event NftSold(
        address nftAddress,
        uint256 indexed soldItemCopyId,
        uint256 indexed soldItemId,
        address indexed buyer,
        address seller,
        string soldItemBaseURI,
        uint256 amountEarned,
        uint256 time
    );

    //Emitted when a collection is created
    event CollectionCreated(
        uint256 collectionId,
        address indexed fundingRecipient,
        uint256 creatorFee,
        address indexed owner,
        uint256 time
    );

    //Emitted when a collection is created
    event CollectionUpdated(
        uint256 collectionId,
        address indexed fundingRecipient,
        uint256 creatorFee,
        address indexed owner,
        uint256 time
    );

    //Emitted when a Item is listed for sell
    event TokenListed(
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 itemId,
        address indexed owner,
        uint256 price,
        address creator,
        uint256 creatorFee,
        uint256 time,
        uint256 collectionId
    );

    event CollectionDeleted(address owner, uint256 collectionId, uint256 time);

    event ItemListingCanceled(address owner, uint256 tokenId, uint256 time);

    event AddressChanged(address oldAddress, address newAddress);
    event SharedInterfaceChanged(ICloudaxShared oldAddress, address newAddress);

    constructor(address _cloudaxShared){
        cloudaxShared = ICloudaxShared(_cloudaxShared);
    }
    
    modifier isListed(address nftAddress, uint256 tokenId) {
        ListedToken memory listing = s_listedTokens[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NotListed(tokenId);
        }
        _;
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

    function setShared(address newAddress) external onlyOwner {
        emit SharedInterfaceChanged(cloudaxShared, newAddress);
        cloudaxShared = ICloudaxShared(newAddress);
    }

    function _currentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    // This function is used to update or set the CloudaxNFT Base for Opensea compatibiblity
    function setContractBaseURI(string memory __contractBaseURI)
        external
        onlyOwner
    {
        s_contractBaseURI = __contractBaseURI;
    }


    /// @notice Creates or mints a new copy or token for the given item, and assigns it to the buyer
    /// @param itemId The id of the item selected to be purchased
    /// Look at buying the first copy for every created
    function buyItemCopy(
        address payable _fundingRecipient,
        uint256 collectionId,
        string memory itemId,
        string memory _tokenUri,
        uint256 _price,
        uint256 _qty,
        uint256 _supply
    ) external payable nonReentrant 
    isValidated(_fundingRecipient,_supply) 
    {

        require(
            _qty >= 1,
            "Must buy atleast one nft"
        );
        require(
            collectionId <= cloudaxShared.nextCollectionId(),
            "Collection does not exist"
        );

        ListedItem memory listings = s_listedItems[address(this)][cloudaxShared.getItemId(itemId)];
        if (listings.itemId != cloudaxShared.nextItemId() || listings.supply == 0 || cloudaxShared.nextItemId() == 0 )  {
            cloudaxShared.createItem(
                collectionId,
                itemId,
                _fundingRecipient,
                _price,
                _supply
            );
        }
    
        ListedItem memory listing = s_listedItems[address(this)][cloudaxShared.nextItemId()];
        Collection memory collection = s_collection[collectionId];

        // Validations
        if (listing.supply <= 0) {
            revert SupplyDoesNotExist({availableSupply: listing.supply});
        }
        // Check that the item's ID is not Zero(0).
        if (cloudaxShared.nextItemId() <= 0) {
            revert InvalidItemId({itemId: cloudaxShared.nextItemId()});
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
        if (listing.price.mul(_qty) != msg.value) {
            revert InsufficientFund({price: listing.price.mul(_qty), allowedFund: msg.value});
        }

        // Increment the number of copies or tokens sold from this Item.
        listing.numSold = listing.numSold + _qty;

        // https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]/[TOKEN_ID]
        // Where _tokenBaseURI = https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
        // Generating a metadata URL for the new copy of the ITEM or Token that was generated.

        //Deduct the service fee
        uint256 serviceFee = msg.value.mul(cloudaxShared.getServiceFee()).div(100);
        uint256 royalty = msg.value.mul(collection.creatorFee).div(100);
        uint256 finalAmount = msg.value.sub(serviceFee.add(royalty));


        // Adding the newly earned money to the total amount a user has earned from an Item.
        cloudaxShared.addPlatformEarning(serviceFee);
        cloudaxShared.setIndivivdualEarningInPlatform(listings.fundingRecipient, finalAmount);
        cloudaxShared.setIndivivdualEarningInPlatform(collection.fundingRecipient, royalty);
        cloudaxShared.addTotalAmount(msg.value);

        // Send funds to the funding recipient.
        cloudaxShared.sendFunds(listings.fundingRecipient, finalAmount);
        cloudaxShared.sendFunds(collection.fundingRecipient, royalty);


        emit ItemCopySold(
            cloudaxShared.getItemsSold(),
            _qty,
            collection.fundingRecipient,
            msg.sender,
            finalAmount,
            listing.numSold
        );

        emit ItemCopySold1(
            itemId,
            _tokenUri
        );
        
        
        // Mint a new copy or token from the Item for the buyer
        cloudaxShared.safeMint(_qty, _tokenUri, cloudaxShared.nextItemId());
        // Store the mapping of the ID a sold item's copy or token id to the Item being purchased.


        // emit event of item sold, ths also capture the all tokens minted/purshed under a particular item 
        // NB. event is used over the mapping to optimize for gas usage.
        s_soldItems[address(this)][cloudaxShared.getItemsSold()] = SoldItem({
            nftAddress: address(this),
            tokenIdFrom: cloudaxShared.getItemsSold(),
            quantity: _qty,
            itemId: cloudaxShared.nextItemId(),
            buyer: payable(msg.sender),
            creator: collection.fundingRecipient,
            itemBaseURI: _tokenUri,
            amountEarned: finalAmount
        });


        s_listedItems[address(this)][cloudaxShared.nextItemId()] = listing;
    }
    
    function listToken(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 collectionId,
        address payable fundingRecipient
    ) external {
        cloudaxShared.ownerCheck(nftAddress, tokenId, msg.sender);
        require(
            fundingRecipient == msg.sender,
            "Only the nft owner can receive payment for nft"
        );

        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }

        if (nftAddress == address(this)){
            s_listedTokens[nftAddress][tokenId] = ListedToken({
                nftAddress: nftAddress,
                itemId: 0,
                tokenId: tokenId,
                fundingRecipient: fundingRecipient,
                price: price,
                creator: s_collection[collectionId].fundingRecipient,
                royaltyBPS: s_collection[collectionId].creatorFee,
                collectionId: collectionId
            });

                emit TokenListed
            (
                nftAddress, 
                tokenId, 
                0, 
                msg.sender, 
                price,
                s_collection[collectionId].fundingRecipient,
                s_collection[collectionId].creatorFee, 
                block.timestamp,
                collectionId
            );
        }

        s_listedTokens[nftAddress][tokenId] = ListedToken({
            nftAddress: nftAddress,
            itemId: 0,
            tokenId: tokenId,
            fundingRecipient: fundingRecipient,
            price: price,
            creator: address(0),
            royaltyBPS: 0,
            collectionId: 0
        });


        emit TokenListed
        (
            nftAddress, 
            tokenId, 
            0, 
            msg.sender, 
            price,
            address(0),
            0, 
            block.timestamp,
            0
        );

       
    }

    function updateListing
    (
        address nftAddress, 
        uint256 tokenId, 
        uint256 newPrice
    )
        external
        isListed(nftAddress, tokenId)
    {
        cloudaxShared.ownerCheck(nftAddress, tokenId, msg.sender);
        ListedToken memory listing = s_listedTokens[nftAddress][tokenId];
        s_listedTokens[nftAddress][tokenId].price = newPrice;
         if (nftAddress == address(this)){
                emit TokenListed
            (
                nftAddress,
                tokenId,
                0,
                msg.sender,
                newPrice,
                listing.creator,
                listing.royaltyBPS,
                block.timestamp,
                listing.collectionId
            );
        }
        emit TokenListed(
            nftAddress,
            tokenId,
            0,
            msg.sender,
            newPrice,
            address(0),
            0,
            block.timestamp,
            0
        );

       
    }

    function cancelListing(address nftAddress, uint256 tokenId)
        external
        isListed(nftAddress, tokenId) 
    {
        cloudaxShared.ownerCheck(nftAddress, tokenId, msg.sender);
        delete (s_listedTokens[nftAddress][tokenId]);
        emit ItemListingCanceled(msg.sender, tokenId, block.timestamp);
        // s_idToItemStatus[tokenId] = TokenStatus.ACTIVE;
    }

    function createCollection(
        uint256 creatorFee,
        address payable fundingRecipient
    ) external {

        if (fundingRecipient == address(0)) {
            revert InvalidAddress();
        }

        cloudaxShared.increaseCollectionId();
        s_collection[cloudaxShared.nextCollectionId()] = Collection({
            fundingRecipient: fundingRecipient,
            creatorFee: creatorFee,
            owner: msg.sender
        });

        emit CollectionCreated(cloudaxShared.nextCollectionId(), fundingRecipient, creatorFee, msg.sender, block.timestamp);
    }

    function updateCollection(
        uint256 collectionId,
        uint256 creatorFee,
        address payable fundingRecipient
    ) external {

        if (fundingRecipient == address(0)) {
            revert InvalidAddress();
        }
        require(
            s_collection[collectionId].owner == msg.sender,
            "Only collection owners can update collection"
            );
        
        s_collection[collectionId] = Collection({
            fundingRecipient: fundingRecipient,
            creatorFee: creatorFee,
            owner: msg.sender
        });

        emit CollectionUpdated(collectionId, fundingRecipient, creatorFee, msg.sender, block.timestamp);
    }

    function deleteCollection(uint256 collectionId)
        external 
    {
        
        require(
            s_collection[collectionId].owner == msg.sender,
            "Only collection owners can delete collection"
            );
        delete (s_collection[collectionId]);
        emit CollectionDeleted(msg.sender, collectionId, block.timestamp);
    }

    /// @notice Creates or mints a new copy or token for the given item, and assigns it to the buyer
    /// @param tokenId The id of the token selected to be purchased
    function buyNft(address nftAddress, uint256 tokenId)
        external
        payable
        isListed(nftAddress, tokenId)
    {
        ListedToken memory listing = s_listedTokens[nftAddress][tokenId];
        address payable creator = listing.fundingRecipient;
        // Check that the buyer approved an amount that is equal or more than the price of the item set by the seller.
        if (listing.price > msg.value) {
            revert InsufficientFund({price: listing.price, allowedFund: msg.value});
        }
        uint256 serviceFee = msg.value.mul(cloudaxShared.getServiceFee()).div(100);
        if (nftAddress == address(this)){
            //Deduct the service fee
            uint256 royalty = msg.value.mul(listing.royaltyBPS).div(100);
            uint256 finalAmount = msg.value.sub(serviceFee.add(royalty));


            // Adding the newly earned money to the total amount a user has earned from an Item.
            cloudaxShared.addPlatformEarning(serviceFee);
            cloudaxShared.setIndivivdualEarningInPlatform(listing.creator, finalAmount);
            cloudaxShared.addTotalAmount(msg.value);
        }
        uint256 finalAmount = msg.value.sub(serviceFee);

        // Update the deposited total for the item.
        // Adding the newly earned money to the total amount a user has earned from an Item.
        cloudaxShared.setIndivivdualEarningInPlatform(creator, finalAmount);
        cloudaxShared.addPlatformEarning(serviceFee);
        cloudaxShared.addTotalAmount(msg.value);

        
        // Send funds to the funding recipient.
        cloudaxShared.sendFunds(creator, finalAmount);

        // transfer nft to buyer
        cloudaxShared.transferNft(nftAddress, creator, msg.sender, tokenId);

        emit NftSold(
            nftAddress,
            tokenId,
            0,
            msg.sender,
            creator,
            "",
            finalAmount,
            block.timestamp
        );
   

    }

    function withdrawEarnings() external onlyOwner {
        if (cloudaxShared.getPlatformEarning() <= 0) {
            revert NoProceeds();
        }

        (bool success, ) = payable(msg.sender).call{value: cloudaxShared.getPlatformEarning()}(
            ""
        );
        if (!success) {
            revert TransferFailed();
        }
        cloudaxShared.setPlatformEarning(0);
    }

    // Getter Functions

    /// @notice Returns contract URI of an NFT to be used on Opensea. e.g. https://cloudaxnftmarketplace.xyz/metadata/opensea-storefront
    function getContractURI() public view returns (string memory) {
        // Concatenate the components, s_contractBaseURI to create contract URI for Opensea.
        return s_contractBaseURI;
    }

}