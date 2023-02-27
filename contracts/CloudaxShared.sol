// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ================================
// CUSTOM ERRORS
// ================================
error QuantityRequired(uint256 supply, uint256 minRequired);
error InvalidAddress();
error CannotSendFund(uint256 senderBalance, uint256 fundTosend);
error CannotSendZero(uint256 fundTosend);
error InvalidItemId(uint256 itemId);
error ItemSoldOut(uint256 supply, uint256 numSold);
error NotEnoughNft(uint256 supply, uint256 numSold, uint256 purchaseQuantityRequest);
error InsufficientFund(uint256 price, uint256 allowedFund);
error TransferFailed();
error NotOwner();
error PriceMustBeAboveZero();


contract CloudaxShared is
    ReentrancyGuard,
    ERC721URIStorage,
    Ownable
{

    using SafeMath for uint256;
    IERC20 internal ERC20Token;


    // The next token ID to be minted.
    uint256 internal _currentItemIndex;
    uint256 internal _currentCollectionIndex;
    // % times 200 = 2%
    uint256 internal constant SERVICE_FEE = 2;
    uint256 internal constant auction = 2;
    uint256 internal s_platformEarning;
    uint256 internal s_totalAmount;
    

    // ================================
    // STRUCTS
    // ================================
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

    

    // webapp itemId(db objectId) to mapping of smart-contract itemId (uint)
    mapping(string => uint256) public s_itemIdDBToItemId;

    // Total amount earned by Seller... mapping of address -> Amount earned
    mapping(address => uint256) internal s_indivivdualEarningInPlatform;

    //Mapping of collectionId to a collection struct
    mapping(uint256 => Collection) public s_collection;

    // mapping of collection to item to TokenId
    mapping(uint256 => mapping(uint256 => uint256)) public s_tokensToItemToCollection;

    mapping(address => mapping(uint256 => ListedItem)) public s_listedItems;

    //Mapping of items to a ListedItem struct
    mapping(address => mapping(uint256 => ListedToken)) public s_listedTokens;


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

    event CollectionDeleted(address owner, uint256 collectionId, uint256 time);

    event ERC20AddressChanged(address oldAddress, address newAddress);


    constructor() ERC721A("Cloudax NFTMarketplace", "CLDX"){}

    // ================================
    // MODIFIERS
    // ================================
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

    modifier isOwner(address nftAddress, uint256 tokenId, address spender) {
        ERC721A nft = ERC721A(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
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

    /// @notice Returns the CloudaxNFT Listing price
    function getServiceFee() public pure returns (uint256) {
        return SERVICE_FEE;
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
    ) internal isValidated(_fundingRecipient,_supply) {

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

    function safeMint(
        uint256 _qty,
        string memory _uri,
        uint256 itemId
    ) internal {
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

    function safeMintOut(
        uint256 _qty,
        string memory _uri,
        uint256 itemId,
        address recipient
    ) internal {
        _safeMint(recipient, _qty);
        uint256 end = _nextTokenId();
        uint256 index = end - _qty;
        ListedItem memory listing = s_listedItems[address(this)][itemId]; // sub for 
        for (uint i = index; i < end; i++) {
            string memory _tURI = string(
                abi.encodePacked(_uri, "/", Strings.toString(i))
            );
            _setTokenURI(i, _tURI);
            s_tokensToItemToCollection[i][listing.itemId] = listing.collectionId;
        }
        
    }  

    /// @notice Sends funds to an address
    /// @param _recipient The address to send funds to
    /// @param _amount The amount of funds to send
    function _sendFunds(address payable _recipient, uint256 _amount) internal {
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

}