// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./CloudaxShared.sol";
import "./interfaces/ICloudaxMarketplace.sol";

////Custom Errors
error NoProceeds();
error SupplyDoesNotExist(uint256 availableSupply);
error NotListed(uint256 tokenId);

//000000000000000000
//www.cloudax.com/meta

contract CloudaxMarketplace is
    CloudaxShared,
    ICloudaxMarketplace
{
    using SafeMath for uint256;

// -----------------------------------VARIABLES-----------------------------------
    
    string internal s_contractBaseURI;

    struct SoldItem {
        address nftAddress;
        uint256 amountEarned;
        address payable buyer;
        string itemBaseURI;
        address payable creator;
        uint256 tokenIdFrom;
        uint256 quantity;
        // uint256 tokenIdTo;
        uint256 itemId;      
    }

        mapping(address => mapping(uint256 => SoldItem)) public s_soldItems;

    
    // Added an additional counter, since _tokenIds can be reduced by burning.
    // And intranal because the marketplace contract will display the total amount.


    ///Mapping an Item to the token copies minted from it.
    // mapping(uint256 => uint256) public s_tokenToListedItem;

    // The amount of funds that have been earned from selling the copies of a given item.
    // mapping(uint256 => uint256) public s_depositedForItem;

    

    //Mapping of Item to a TokenStatus struct
    // mapping(uint256 => TokenStatus) internal s_idToItemStatus;

    // mapping(uint256 => uint256) public depositedForEdition;

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


    event ItemListingCanceled(address owner, uint256 tokenId, uint256 time);


    constructor() {
        _currentItemIndex = _startItemId();
        _currentCollectionIndex = _startCollectionId();
    }

    modifier isReady(uint256 collectionId,uint256 quantity){
        require(
            quantity >= 1,
            "Must buy atleast one nft"
        );
        require(
            collectionId <= _nextCollectionId(),
            "Collection does not exist"
        );
        _;
    }
    

    modifier isListed(address nftAddress, uint256 tokenId) {
        ListedToken memory listing = s_listedTokens[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NotListed(tokenId);
        }
        _;
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

    function setERC20Token(address newToken) external onlyOwner {
        emit ERC20AddressChanged(address(ERC20Token), newToken);
        ERC20Token = IERC20(newToken);
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
    isReady(collectionId, _qty)
    {

        ListedItem memory listings = s_listedItems[address(this)][s_itemIdDBToItemId[itemId]];
        if (listings.itemId != _nextItemId() || listings.supply == 0 || _nextItemId() == 0 )  {
            _createItem(
                collectionId,
                itemId,
                _fundingRecipient,
                _price,
                _supply
            );
        }
    
        ListedItem memory listing = s_listedItems[address(this)][_nextItemId()];
        Collection memory collection = s_collection[collectionId];

        // Validations
        if (listing.supply <= 0) {
            revert SupplyDoesNotExist({availableSupply: listing.supply});
        }
        // Check that the item's ID is not Zero(0).
        if (_nextItemId() <= 0) {
            revert InvalidItemId({itemId: _nextItemId()});
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

        // uint256 fullCost = msg.value.mul(_qty);

        //Deduct the service fee
        uint256 serviceFee = msg.value.mul(SERVICE_FEE).div(100);
        uint256 royalty = msg.value.mul(collection.creatorFee).div(100);
        uint256 finalAmount = msg.value.sub(serviceFee.add(royalty));


        // Adding the newly earned money to the total amount a user has earned from an Item.
        s_platformEarning += serviceFee;
        s_indivivdualEarningInPlatform[listings.fundingRecipient] += finalAmount;
        s_indivivdualEarningInPlatform[collection.fundingRecipient] += royalty;
        s_totalAmount += msg.value;

        // Send funds to the funding recipient.
        _sendFunds(listings.fundingRecipient, finalAmount);
        _sendFunds(collection.fundingRecipient, royalty);


        emit ItemCopySold(
            _nextTokenId(),
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
         safeMint(_qty, _tokenUri, _nextItemId());
        // Store the mapping of the ID a sold item's copy or token id to the Item being purchased.


        // emit event of item sold, ths also capture the all tokens minted/purshed under a particular item 
        // NB. event is used over the mapping to optimize for gas usage.
        s_soldItems[address(this)][_nextTokenId()] = SoldItem({
            nftAddress: address(this),
            tokenIdFrom: _nextTokenId(),
            quantity: _qty,
            itemId: _nextItemId(),
            buyer: payable(msg.sender),
            creator: collection.fundingRecipient,
            itemBaseURI: _tokenUri,
            amountEarned: finalAmount
        });


        s_listedItems[address(this)][_nextItemId()] = listing;
    }
    
    function listToken(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 collectionId,
        address payable fundingRecipient
    ) external isOwner(nftAddress, tokenId, msg.sender) {
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
        isOwner(nftAddress, tokenId, msg.sender)
    {
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
        isOwner(nftAddress, tokenId, msg.sender)
        isListed(nftAddress, tokenId) 
    {
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

        _currentCollectionIndex++;
        s_collection[_nextCollectionId()] = Collection({
            fundingRecipient: fundingRecipient,
            creatorFee: creatorFee,
            owner: msg.sender
        });

        emit CollectionCreated(_nextCollectionId(), fundingRecipient, creatorFee, msg.sender, block.timestamp);
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
        uint256 serviceFee = msg.value.mul(SERVICE_FEE).div(100);
        if (nftAddress == address(this)){
            //Deduct the service fee
            uint256 royalty = msg.value.mul(listing.royaltyBPS).div(100);
            uint256 finalAmount = msg.value.sub(serviceFee.add(royalty));


            // Adding the newly earned money to the total amount a user has earned from an Item.
            // s_depositedForItem[_nextItemId()] += finalAmount; // optm
            s_platformEarning += serviceFee;
            s_indivivdualEarningInPlatform[listing.creator] += finalAmount;
            s_totalAmount += msg.value;
        }
        uint256 finalAmount = msg.value.sub(serviceFee);

        // Update the deposited total for the item.
        // Adding the newly earned money to the total amount a user has earned from an Item.
        s_indivivdualEarningInPlatform[
            creator
        ] += finalAmount;
        s_platformEarning += serviceFee;
        s_totalAmount += msg.value;

        
        // Send funds to the funding recipient.
        _sendFunds(creator, finalAmount);

        // transfer nft to buyer
         IERC721A(nftAddress).safeTransferFrom(creator, msg.sender, tokenId);

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

    /// @notice Returns token metadata URI (metadata URL). e.g. https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721URIStorage)
        returns (string memory)
    {
        if (!_exists(_tokenId)) {
            revert InvalidItemId({itemId: _tokenId});
        }

        return super.tokenURI(_tokenId);
    }

    function _burn(uint256 _tokenId)
        internal
        override(ERC721URIStorage)
        onlyOwner
    {
        super._burn(_tokenId);
    }

    function withdrawEarnings() external onlyOwner {
        if (s_platformEarning <= 0) {
            revert NoProceeds();
        }

        (bool success, ) = payable(msg.sender).call{value: s_platformEarning}(
            ""
        );
        if (!success) {
            revert TransferFailed();
        }
        s_platformEarning = 0;
    }

    // Getter Functions

    /// @notice Returns contract URI of an NFT to be used on Opensea. e.g. https://cloudaxnftmarketplace.xyz/metadata/opensea-storefront
    function getContractURI() public view returns (string memory) {
        // Concatenate the components, s_contractBaseURI to create contract URI for Opensea.
        return s_contractBaseURI;
    }

}