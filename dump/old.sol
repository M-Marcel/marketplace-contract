// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "./NFT.sol";

// error NftMarketplace__NotApprovedForMarketplace();
// error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
// error NftMarketplace__NotOwner();
// error NftMarketplace__ItemHasBeenSold(nftAddress, tokenId);
// error NftMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
// error NftMarketplace__NoProceeds();
// error NftMarketplace__TransferFailed();

 ////Custom Errors
    error InvalidAddress();
    error QuantityRequired(uint256 sent, uint256 minRequired);
    error QuantityDoesNotExist(uint256 availableQuantity);
    error InvalidItemId(uint256 itemId);
    error ItemSoldOut(uint256 quantity, uint256 numSold);
    error InsufficientFund(uint256 price, uint256 allowedFund);
    error NotListed(itemId);
    error NotOwner();
    error PriceMustBeAboveZero();
    error NotApprovedForMarketplace();

contract NftMarketplace is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable {

    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private tokenId;
    CountersUpgradeable.Counter private listedItemId;

    uint256 listPrice public;
    address payable owner;
    // Index of auctions
    uint256 public index = 0;

///This struct describes the main NFT of a user
    struct  UserToken {
        uint256 tokenId;
        string name;
        string symbol;
        address owner;
        address tokenAddress;
    }
    
    // structs for an item to be listed
    struct ListedItem {
        uint256 itemId;
        address payable seller;
        address payable owner;
        uint256 price;
        uint32 numSold;
        uint32 quantity;

    }

    // Structure to define auction properties
    struct Auction {
        uint256 index; // Auction Index
        address addressNFTCollection; // Address of the ERC721 NFT Collection contract
        address addressPaymentToken; // Address of the ERC20 Payment Token contract
        uint256 nftId; // NFT Id
        address creator; // Creator of the Auction
        address payable currentBidOwner; // Address of the highest bider
        uint256 currentBidPrice; // Current highest bid for the auction
        uint256 endAuction; // Timestamp for the end day&time of the auction
        uint256 bidCount; // Number of bid placed on the auction
    }

    ///Mapping a user's address to the tokens created
    mapping(address => UserToken[]) private addressToTokens;
    //Mapping of items to a Item struct
    mapping(uint256 => ListedItem) public listedItems;
    ///Mapping an Item to the token copies minted from it.
    mapping(uint256 => uint256) public tokenToListedItem;
    // The amount of funds that have been earned from selling the copies of a given item.
    mapping(uint256 => uint256) public depositedForItem;
    // Total amount earned by Seller... mapping of address -> Amount earned
    mapping(address => uint256) private s_proceeds;
    // Array will all auctions
    Auction[] private allAuctions;
    

// ================================
    // EVENTS
    // ================================

    ///Emitted when a Item is created
    event ItemCreated(
        uint256 indexed itemId,
        address owner,
        uint256 price,
        uint32 quantity
    );

    ///Emitted when a new NFT is created
    event tokenCreated(
        uint256 indexed tokenId,
        string indexed name,
        string indexed symbol,
        address indexed wner,
        address indexed tokenAddress,
        string contractBaseURI
    );

    ///Emitted when a copy of an item is sold
    event itemCopySold(
        uint256 indexed soldItemCopyId,
        uint256 indexed soldItemId,
        uint32 indexed numSold,
        address indexed buyer,
        string indexed soldItemBaseURI
    );
    // Emitted when item is listed
    event ItemListed(
        uint256 indexed itemId,
        address indexed seller,
        address indexed owner,
        uint256 indexed price
        uint32 indexed numSold
        uint32 indexed quantity
    );
     // Public event to notify that a new auction has been created
    event NewAuction(
        uint256 index,
        address addressNFTCollection,
        address addressPaymentToken,
        uint256 nftId,
        address mintedBy,
        address currentBidOwner,
        uint256 currentBidPrice,
        uint256 endAuction,
        uint256 bidCount
    );

    // Public event to notify that a new bid has been placed
    event NewBidOnAuction(uint256 auctionIndex, uint256 newBid);

    // Public event to notif that winner of an
    // auction claim for his reward
    event NFTClaimed(uint256 auctionIndex, uint256 nftId, address claimedBy);

    // Public event to notify that the creator of
    // an auction claimed for his money
    event TokensClaimed(uint256 auctionIndex, uint256 nftId, address claimedBy);

    // Public event to notify that an NFT has been refunded to the
    // creator of an auction
    event NFTRefunded(uint256 auctionIndex, uint256 nftId, address claimedBy);
    
// Modifier
    // modifier notListed(
    //     uint256 tokenId
    // ) {
    //     ListedItem memory listedItems = listedItems[tokenId];
    //     if (listing.price > 0) {
    //         revert AlreadyListed(tokenId);
    //     }
    //     _;
    // }

    modifier isListed(uint256 _itemId) {
        ListedItem memory listedItems = listedItems[_itemId];
        if (listing.price <= 0) {
            revert NotListed(_itemId);
        }
        _;
    }

    modifier isOwner(
        address _tokenAddress,
        address spender
    ) {
        IERC721 nft = IERC721(_tokenAddress);
        address owner = CloudaxNFT.ownerOf(_tokenAddress);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }

    modifier isNotSold(uint256 _itemId) {
        ListedItem memory listedItems = listedItems[_itemId];
        if (listedItems.numSold >= listedItems.quantity) {
            revert ItemSoldOut(uint256 quantity, uint256 numSold);
        }
        _;
    }

    /// @notice Creates a new NFT for a user
    /// @param _owner The address of the user that owns this NFT
    /// @param _name The name of this NFT
    /// @param _symbol The symbol of this NFT
    /// @param _contractBaseURI The address of the new NFT to be created for a user
    function createToken(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _contractBaseURI
    ) external returns (bool) {
        // Spin up new ERC721 token contract for the user
        CloudaxNFT erc721 = new CloudaxNFT(); 
        erc721.initialize(_owner, _name, _symbol, _contractBaseURI);

        address _tokenAddress = address(erc721);

        // Save token data
        address sender = msg.sender;
        tokenId.increment();
        uint256 currentTokenId = tokenId.current();

        UserToken[] storage tokens = addressToTokens[sender];
        tokens.push(
            UserToken(currentTokenId, _name, _symbol, sender, _tokenAddress)
        );
        addressToTokens[sender] = tokens;
        // Emit and return
        emit tokenCreated(
            currentTokenId,
            _name,
            _symbol,
            sender,
            _tokenAddress,
            _contractBaseURI
        );

    // Token (NFT) created but not listed i.e invoke line 48 ??
        return true;
    }

    function listItem(
        address itemId,
        uint256 tokenId,
        _tokenAddress,
        uint256 price,
        uint256 quantity
    )
        external
        payable
        nonReentrant
        // notListed(tokenId, msg.sender)
        isOwner(_tokenAddress, msg.sender)
    {
        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }
        // require(msg.value == listingPrice, "Price must be equal to listing price");
        // _itemIds.increment(); //add 1 to the total number of items ever created
        // uint256 itemId = _itemIds.current();

        //transfer ownership of the nft to the contract itself
        IERC721(CloudaxNFT.address).transferFrom(msg.sender, address(this), _tokenAddress);

        IERC721 nft = IERC721(CloudaxNFT.address);
        if (nft.getApproved(_tokenAddress) != address(this)) {
            revert NotApprovedForMarketplace();
        }
        listedItems[itemId]; = ListedItem(
            itemId,
            payable(msg.sender), //address of the seller putting the nft up for sale
            payable(address(0)), //no owner yet (set owner to empty address)
            price,
            0,
            quantity
        );
        emit ItemListed(itemId, msg.sender, 0,  price, 0, quantity);
        
    }

    /// @notice Creates or mints a new copy or token for the given item, and assigns it to the buyer
    /// @param _itemId The id of the item selected to be purchased
    function buyItemCopy(uint256 _itemId, string memory _tokenBaseURI)
        external
        payable
        isListed(_itemId)
        isNotSold(_itemId)
    {
        // Caching variables locally to reduce reads
        uint256 price = listedItems[_itemId].price;
        uint32 quantity = listedItems[_itemId].quantity;
        uint32 numSold = listedItems[_itemId].numSold;

        // Validations
        // Check that the item's quantity is more than zero(0).
        if (quantity <= 0) {
            revert QuantityDoesNotExist({
                    availableQuantity: quantity
                });
        }
        // Check that the item's ID is not Zero(0).
        if (_itemId <= 0) {
            revert InvalidItem({
                    item: _itemId
                });
        }
        // Check that there are still some copies or tokens of the item that are available for purchase.
        if (quantity >= numSold) {
            revert ItemSoldOut({
                    quantity: quantity,
                    numSold: numSold
                });
        }
        // Check that the buyer approved an amount that is equal or more than the price of the item set by the seller.
        if (price > msg.value) {
            revert InsufficientFund({
                    price: price,
                    allowedFund: msg.value
                });
        }
        // Update the deposited total for the item.
        // Adding the newly earned money to the total amount a user has earned from an Item.
        depositedForItem[_itemId] += msg.value;

        // Increment the number of copies or tokens sold from this Item.
        listedItems[_itemId].numSold++;
        itemId.increment();
        uint256 newTokenId = itemId.current();

        // https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]/[TOKEN_ID]
        // Where _tokenBaseURI = https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
        // Generating a metadata URL for the new copy of the ITEM or Token that was generated.

        _tokenBaseURI = string(
            abi.encodePacked(
                _tokenBaseURI,
                "/",
                StringsUpgradeable.toString(newTokenId)
            )
        );

        //
        // We don't send the money to user
        // Rather we have them withdraw the money
        /* (Mapping yet to be implemented)
        s_proceeds[listedItem.seller] = s_proceeds[listedItem.seller] + msg.value;
        s_marketplaceProceeds[listedItem.seller] = s_marketplaceProceeds[listedItem.seller] + listingPrice;
        */
        listedItems[_itemId].owner = payable(msg.sender);
        // _itemsSold.increment();
        // Mint a new copy or token from the Item for the buyer, using the `newTokenId`.
        safeMint(msg.sender, newTokenId, _tokenBaseURI);
        // Store the mapping of the ID a sold item's copy or token id to the Item being purchased.
        tokenToListedItem[newTokenId] = _itemId;

        //??
        // IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
        // check to make sure the NFT was transfered
        emit itemCopySold(
            newTokenId,
            _itemId,
            listedItems[_itemId].numSold,
            msg.sender,
            _tokenBaseURI
        );
    }

    function safeMint(
        address _to,
        uint256 _tokenId,
        string memory _uri
    ) private
    {
        _safeMint(_to, _tokenId);
        _setTokenURI(_tokenId, _uri);
    }

    /// @notice Returns token metadata URI (metadata URL). e.g. https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        
        if (!_exists(_tokenId)) {
            revert InvalidItemId({
                    itemId: _tokenId
                });
        }

        return super.tokenURI(_tokenId);
    }


    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // Getter functions
    function getListing(uint256 tokenId)
        external
        view
        returns (Listing memory)
    {
        return listedItems[_itemId];
    }

    // function getListingPrice() public view returns (uint256){
    //     return listingPrice;
    // }
    
    // Have yet decided if there would be a listin price 

    // function setListingPrice(uint _price) external onlyOwner returns(uint) {
    //      if(msg.sender == address(this) ){
    //          listingPrice = _price;
    //      }
    //      return listingPrice;
    // }

    // function getProceeds(address seller) external view returns (uint256) {
    //     return s_proceeds[seller];
    // }
}