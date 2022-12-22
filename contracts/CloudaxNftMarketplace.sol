// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
// pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "contracts/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// 000000000000000000
// www.cloudax.metadata

////Custom Errors
error InvalidAddress();
error NoProceeds();
error TransferFailed();
error NotOwner();
error PriceMustBeAboveZero();
error QuantityRequired(uint256 supply, uint256 minRequired);
error SupplyDoesNotExist(uint256 availableSupply);
error InvalidItemId(uint256 itemId);
error NotListed(uint256 tokenId);
error ItemSoldOut(uint256 supply, uint256 numSold);
error NotEnoughNft(uint256 supply, uint256 numSold, uint256 purchaseQuantityRequest);
error InsufficientFund(uint256 price, uint256 allowedFund);
error CannotSendFund(uint256 senderBalance, uint256 fundTosend);
error CannotSendZero(uint256 fundTosend);


contract CloudaxNftMarketplacevvv is
    ReentrancyGuard,
    ERC721URIStorage,
    Ownable
{
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // The next token ID to be minted.
    uint256 private _currentItemIndex;
    uint256 private _currentCollectionIndex;
    string private s_contractBaseURI;

    // % times 200 = 2%
    uint256 private constant SERVICE_FEE = 2;
    uint256 private s_platformEarning;
    uint256 private s_totalAmount;
    // Added an additional counter, since _tokenIds can be reduced by burning.
    // And intranal because the marketplace contract will display the total amount.

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

    struct Collection{
        address payable fundingRecipient;
        uint256 creatorFee;
        address owner;
    }

    // Structure to define auction properties
    // struct Auction {
    //     uint256 index; // Auction Index
    //     address addressNFTCollection; // Address of the ERC721 NFT Collection contract
    //     address addressPaymentToken; // Address of the ERC20 Payment Token contract
    //     uint256 nftId; // NFT Id
    //     address creator; // Creator of the Auction
    //     address payable currentBidOwner; // Address of the highest bider
    //     uint256 currentBidPrice; // Current highest bid for the auction
    //     uint256 endAuction; // Timestamp for the end day&time of the auction
    //     uint256 bidCount; // Number of bid placed on the auction
    // }

    //Mapping of items to a ListedItem struct
     mapping(address => mapping(uint256 => ListedItem)) public s_listedItems;

     //Mapping of items to a ListedItem struct
     mapping(address => mapping(uint256 => ListedToken)) public s_listedTokens;

    //Mapping of items to a SoldItem struct
    mapping(address => mapping(uint256 => SoldItem)) public s_soldItems;

    //Mapping of collectionId to a collection struct
    mapping(uint256 => Collection) public s_collection;

    // mapping of collection to item to TokenId
    mapping(uint256 => mapping(uint256 => uint256)) public s_tokensToItemToCollection;



    ///Mapping an Item to the token copies minted from it.
    // mapping(uint256 => uint256) public s_tokenToListedItem;

    // The amount of funds that have been earned from selling the copies of a given item.
    mapping(uint256 => uint256) public s_depositedForItem;

    // webapp itemId(db objectId) to mapping of smart-contract itemId (uint)
    mapping(string => uint256) public s_itemIdDBToItemId;

    // Total amount earned by Seller... mapping of address -> Amount earned
    mapping(address => uint256) private s_indivivdualEarningInPlatform;

    //Mapping of Item to a TokenStatus struct
    mapping(uint256 => TokenStatus) private s_idToItemStatus;

    // mapping(uint256 => uint256) public depositedForEdition;

    // ================================
    // EVENTS
    // ================================

    ///Emitted when a Item is created
    event ItemCreated(
        address nftAddress,
        uint256 indexed itemId,
        string indexed itemIdDB,
        address indexed fundingRecipient,
        uint256 price,
        uint256 supply,
        uint256 royaltyBPS,
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

    //Emitted when a collection is created
    event CollectionCreated(
        address indexed fundingRecipient,
        uint256 creatorFee,
        address indexed owner,
        uint256 time
    );

    //Emitted when a collection is created
    event CollectionUpdated(
        address indexed fundingRecipient,
        uint256 creatorFee,
        address indexed owner,
        uint256 time
    );

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

    event itemIdPaired(string indexed itemIdDB, uint256 indexed itemId);

    // event ServiceFeeUpgraded(uint256 oldFee, uint256 newFee, uint256 time);

    event ItemListingCanceled(address owner, uint256 tokenId, uint256 time);

    event CollectionDeleted(address owner, uint256 collectionId, uint256 time);

    enum TokenStatus {
        DEFAULT,
        ACTIVE,
        ONSELL,
        SOLDOUT,
        ONAUCTION,
        BURNED
    }

    constructor() ERC721A("Cloudax Marketplace", "CLDX") {
        // s_contractBaseURI = "";
        _currentItemIndex = _startItemId();
        _currentCollectionIndex = _startCollectionId();
    }

    modifier isOwner(address nftAddress, uint256 tokenId, address spender) {
        ERC721A nft = ERC721A(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
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

    // modifier insufficientPrice(uint256 price){
    //     if (price > msg.value) {
    //         revert InsufficientFund({price: listing.price, allowedFund: msg.value});
    //     }
    // }

    

    modifier isListed(address nftAddress, uint256 tokenId) {
        ListedToken memory listing = s_listedTokens[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NotListed(tokenId);
        }
        _;
    }

    /**
     * @dev Returns the starting token ID.
     * To change the starting token ID, please override this function.
     */
    function _startItemId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the next token ID to be minted.
     */
    function _nextItemId() internal view virtual returns (uint256) {
        return _currentItemIndex;
    }

    /**
     * @dev Returns the starting collection ID.
     * To change the starting collection ID, please override this function.
     */
    function _startCollectionId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the next collection ID to be minted.
     */
    function _nextCollectionId() internal view virtual returns (uint256) {
        return _currentCollectionIndex;
    }

    // This function is used to update or set the CloudaxNFT Base for Opensea compatibiblity
    function setContractBaseURI(string memory __contractBaseURI)
        public
        onlyOwner
    {
        s_contractBaseURI = __contractBaseURI;
    }

    // This function is used to update or set the CloudaxNFT Listing price
    // function setServiceFee(uint256 __serviceFee) public onlyOwner {
    //     uint256 oldFee = s_serviceFee;
    //     s_serviceFee = __serviceFee;
    //     emit ServiceFeeUpgraded(oldFee, s_serviceFee, block.timestamp);
    // }

    /// @notice Creates a new NFT item.
    /// @param _fundingRecipient The account that will receive sales revenue.
    /// @param _price The price at which each copy of NFT item or token from a NFT item will be sold, in ETH.
    /// @param _supply The maximum number of NFT item's copy or tokens that can be sold.
    function _createItem(
        uint256 collectionId,
        string memory itemId,
        address payable _fundingRecipient,
        uint256 _price,
        uint256 _supply
    ) private isValidated(_fundingRecipient,_supply) {

        _currentItemIndex++;
        emit itemIdPaired(itemId, _nextItemId());
        s_itemIdDBToItemId[itemId] = _nextItemId();
        Collection memory collection = s_collection[collectionId];
        s_listedItems[address(this)][_nextItemId()] = ListedItem({
            nftAddress: address(this),
            numSold: 0,
            royaltyBPS: collection.creatorFee,
            fundingRecipient: _fundingRecipient,
            supply: _supply,
            price: _price,
            itemId: _nextItemId(),
            collectionId: collectionId
        });

        s_idToItemStatus[_nextItemId()] = TokenStatus.ONSELL;

        emit ItemCreated(
            address(this),
            _nextItemId(),
            itemId,
            _fundingRecipient,
            _price,
            _supply,
            collection.creatorFee,
            block.timestamp
        );


    }

    /// @notice Creates or mints a new copy or token for the given item, and assigns it to the buyer
    /// @param itemId The id of the item selected to be purchased
    function buyItemCopy(
        address payable _fundingRecipient,
        uint256 collectionId,
        string memory itemId,
        string memory _tokenUri,
        uint256 _price,
        uint256 _qty,
        uint256 _supply
    ) external payable nonReentrant isValidated(_fundingRecipient,_supply) {
        // uint256 id = s_itemIdDBToItemId[itemId];
        require(
            _qty >= 1,
            "Must buy atleast one nft"
        );
        require(
            collectionId <= _nextCollectionId(),
            "Collection does not exist"
        );
        ListedItem memory listings = s_listedItems[address(this)][s_itemIdDBToItemId[itemId]];
        // uint256 supply = listings.supply;
        if (listings.itemId != _nextItemId() || listings.supply == 0 || _nextItemId() == 0 )  {
            _createItem(
                collectionId,
                itemId,
                _fundingRecipient,
                _price,
                _supply
            );
        }
    
        // uint256 itemID = _nextItemId();
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
            s_idToItemStatus[_nextItemId()] = TokenStatus.SOLDOUT;
            revert ItemSoldOut({supply: listing.supply, numSold: listing.numSold});
        }
        // Check that there will be enough copies or tokens of the item to fulfil purchase order.
        if (listing.numSold.add(_qty) > listing.supply) {
            revert NotEnoughNft({supply: listing.supply, numSold: listing.numSold, purchaseQuantityRequest: _qty});
        }
        // Check that the buyer approved an amount that is equal or more than the price of the item set by the seller.
        if (listing.price > msg.value) {
            revert InsufficientFund({price: listing.price, allowedFund: msg.value});
        }

        // Increment the number of copies or tokens sold from this Item.
        listing.numSold = listing.numSold + _qty;

        // https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]/[TOKEN_ID]
        // Where _tokenBaseURI = https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
        // Generating a metadata URL for the new copy of the ITEM or Token that was generated.

        //Deduct the service fee
        uint256 serviceFee = msg.value.mul(SERVICE_FEE).div(100);
        uint256 royalty = msg.value.mul(collection.creatorFee).div(100);
        uint256 finalAmount = msg.value.sub(serviceFee.add(royalty));


        // Adding the newly earned money to the total amount a user has earned from an Item.
        s_depositedForItem[_nextItemId()] += finalAmount; // optm
        s_platformEarning += serviceFee;
        s_indivivdualEarningInPlatform[listings.fundingRecipient] += finalAmount;
        s_indivivdualEarningInPlatform[collection.fundingRecipient] += royalty;
        s_totalAmount += msg.value;

        // Send funds to the funding recipient.
        _sendFunds(listings.fundingRecipient, finalAmount);
        _sendFunds(collection.fundingRecipient, royalty);
        
        // Mint a new copy or token from the Item for the buyer
         safeMint(_qty, _tokenUri, _nextItemId());
        // Store the mapping of the ID a sold item's copy or token id to the Item being purchased.
        // s_tokenToListedItem[_nextTokenId()] = itemID;
        s_idToItemStatus[_nextTokenId()] = TokenStatus.ACTIVE;


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

        emit ItemCopySold(
            _nextTokenId(),
            _qty,
            collection.fundingRecipient,
            msg.sender,
            finalAmount,
            listing.numSold
        );

        s_listedItems[address(this)][_nextItemId()] = listing;

        emit ItemCopySold1(
            itemId,
            _tokenUri
        );
    }
    
    function listToken(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 collectionId,
        address payable fundingRecipient
    ) public isOwner(nftAddress, tokenId, msg.sender) {
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

        s_idToItemStatus[tokenId] = TokenStatus.ONSELL;

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
        s_idToItemStatus[tokenId] = TokenStatus.ACTIVE;
    }

    function createCollection(
        uint256 creatorFee,
        address payable fundingRecipient
    ) public {

        if (fundingRecipient == address(0)) {
            revert InvalidAddress();
        }

        _currentCollectionIndex++;
        s_collection[_nextCollectionId()] = Collection({
            fundingRecipient: fundingRecipient,
            creatorFee: creatorFee,
            owner: msg.sender
        });

        emit CollectionCreated(fundingRecipient, creatorFee, msg.sender, block.timestamp);
    }

    function updateCollection(
        uint256 collectionId,
        uint256 creatorFee,
        address payable fundingRecipient
    ) public {

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

        emit CollectionUpdated(fundingRecipient, creatorFee, msg.sender, block.timestamp);
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
            s_depositedForItem[_nextItemId()] += finalAmount; // optm
            s_platformEarning += serviceFee;
            s_indivivdualEarningInPlatform[listing.creator] += finalAmount;
            s_totalAmount += msg.value;
        }
        uint256 finalAmount = msg.value.sub(serviceFee);

        // Update the deposited total for the item.
        // Adding the newly earned money to the total amount a user has earned from an Item.
        s_depositedForItem[tokenId] += finalAmount;
        s_indivivdualEarningInPlatform[
            creator
        ] += finalAmount;
        s_platformEarning += serviceFee;
        s_totalAmount += msg.value;

        
        // Send funds to the funding recipient.
        _sendFunds(creator, finalAmount);

        // transfer nft to buyer
         IERC721A(nftAddress).safeTransferFrom(creator, msg.sender, tokenId);

        s_idToItemStatus[tokenId] = TokenStatus.ACTIVE;


        //  s_soldItems[nftAddress][tokenId] = SoldItem({
        //     nftAddress: nftAddress,
        //     tokenId: tokenId,
        //     itemId: 0,
        //     buyer: payable(msg.sender),
        //     creator: creator,
        //     tokenBaseURI: "",
        //     amountEarned: finalAmount
        // });

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

    /// @notice Sends funds to an address
    /// @param _recipient The address to send funds to
    /// @param _amount The amount of funds to send
    function _sendFunds(address payable _recipient, uint256 _amount) private {
        if (_amount <= 0) {
            revert CannotSendZero({fundTosend: _amount});
        }

        (bool success, ) = _recipient.call{value: _amount}("");
        if (!success) {
            revert CannotSendFund({
                senderBalance: address(_recipient).balance,
                fundTosend: _amount
            });
        }
    }

    function safeMint(
        uint256 _qty,
        string memory _uri,
        uint256 itemId
    ) private {
        _safeMint(msg.sender, _qty);
        uint256 end = _nextTokenId();
        uint256 index = end - _qty;
        ListedItem memory listing = s_listedItems[address(this)][itemId];
        for (uint i = index; i < end; i++) {
            string memory _tURI = string(
                abi.encodePacked(_uri, "/", Strings.toString(i))
            );
            _setTokenURI(i, _tURI);
            s_tokensToItemToCollection[i][listing.itemId] = listing.collectionId;
        }
        
    }

    // function safeMint(
    //     uint256 nextTokenId
    // ) private {

    //     MintToken memory mint = s_mintToken[nextTokenId];
    //     _safeMint(msg.sender, mint.quantity);
    //     uint256 end = nextTokenId;
    //     uint256 index = end - mint.quantity;
    //     for (uint i = index; i < end; index++) {

    //         string memory tokenBaseURI = string(
    //             abi.encodePacked(mint.tokenBaseUri, "/", Strings.toString(index))
    //         );
    //         _setTokenURI(index, tokenBaseURI);
    //     }
        
    // }

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
        // s_totalToken.decrement();
        s_idToItemStatus[_tokenId] = TokenStatus.BURNED;
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

    /// @notice Returns the CloudaxNFT Listing price
    function getServiceFee() public pure returns (uint256) {
        return SERVICE_FEE;
    }


    function getTokenStatus(uint256 tokenId)
        external
        view
        returns (TokenStatus)
    {
        return s_idToItemStatus[tokenId];
    }

    function getItemsSold() public view returns (uint256) {
        return _nextTokenId();
    }

    function getItemsCreated() public view returns (uint256) {
        return _currentItemIndex;
    }

    function getCollectionCreated() public view returns (uint256) {
        return _currentCollectionIndex;
    }

}
