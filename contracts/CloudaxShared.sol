// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ICloudaxShared.sol";

// ================================
// CUSTOM ERRORS
// ================================
error QuantityRequired(uint256 supply, uint256 minRequired);
error InvalidAddress();
error CannotSendFund(uint256 senderBalance, uint256 fundTosend);
error CannotSendZero(uint256 fundTosend);
error InvalidItemId(uint256 itemId);
error NotOwner();
error NotAuthorized();


contract CloudaxShared is
    ICloudaxShared,
    ReentrancyGuard,
    ERC721URIStorage,
    Ownable
{

    using SafeMath for uint256;
    IERC20 internal ERC20Token;


    // The next token ID to be minted.
    uint256 internal _currentItemIndex;
    uint256 internal _currentCollectionIndex;
    uint256 internal constant SERVICE_FEE = 2;
    uint256 internal s_platformEarning;
    uint256 internal s_totalAmount;

   // Made public for test purposes
    address public marketplace;
    address public auction;
    address public offer;
    

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
    mapping(string => uint256) internal s_itemIdDBToItemId;

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
    
    event itemIdPaired(string indexed itemIdDB, uint256 indexed itemId);

    event CollectionDeleted(address owner, uint256 collectionId, uint256 time);

    event ERC20AddressChanged(address oldAddress, address newAddress);

    event AddressChanged(address oldAddress, address newAddress);


    constructor
    (
    address newToken
    ) ERC721A("Cloudax NftMarketplace", "CLDX"){
        ERC20Token = IERC20(newToken);
    }

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

    modifier isAuthorized() {
        
        if (msg.sender != marketplace || msg.sender != auction || msg.sender != offer ) {
            revert NotAuthorized();
        }
        _;
    }

    function setERC20Token(address newToken) external onlyOwner {
        emit ERC20AddressChanged(address(ERC20Token), newToken);
        ERC20Token = IERC20(newToken);
    }

    function getERC20Token() public isAuthorized() view returns(IERC20) {
        return ERC20Token;
    }

    function setAuction(address newAddress) external onlyOwner {
        emit AddressChanged(auction, newAddress);
        auction = newAddress;
    }

    function setMarketplace(address newAddress) external onlyOwner {
        emit AddressChanged(marketplace, newAddress);
        marketplace = newAddress;
    }

    function setOffer(address newAddress) external  onlyOwner {
        emit AddressChanged(offer, newAddress);
        offer = newAddress;
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
    function nextItemId() public view virtual returns (uint256) {
        return _currentItemIndex;
    }

    function increaseItemId() isAuthorized() public {
        _currentItemIndex++;
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
    function nextCollectionId() public view virtual returns (uint256) {
        return _currentCollectionIndex;
    }

    function increaseCollectionId() isAuthorized() public {
         _currentCollectionIndex++;
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

    function getItemId(string memory itemId) public isAuthorized() view returns (uint256) {
        return s_itemIdDBToItemId[itemId];
    }

    function setItemId(string memory itemId, uint256 Id) public isAuthorized() {
         s_itemIdDBToItemId[itemId] = Id;
    }

    function setIndivivdualEarningInPlatform(address user, uint256 amount) public isAuthorized() {
         s_indivivdualEarningInPlatform[user] += amount;
    }

    function setPlatformEarning(uint256 amount) public isAuthorized() {
         s_platformEarning = amount;
    }

    function addPlatformEarning(uint256 amount) public isAuthorized() {
         s_platformEarning += amount;
    }

    function getPlatformEarning() public isAuthorized() view returns(uint256) {
        return s_platformEarning;
    }

    function setTotalAmount(uint256 amount) public isAuthorized() {
         s_totalAmount = amount;
    }

    function addTotalAmount(uint256 amount) public isAuthorized() {
         s_totalAmount += amount;
    }

    function getTotalAmount() public isAuthorized() view returns(uint256) {
        return s_totalAmount;
    }

        /// @notice Creates a new NFT item.
    /// @param _fundingRecipient The account that will receive sales revenue.
    /// @param _price The price at which each copy of NFT item or token from a NFT item will be sold, in ETH.
    /// @param _supply The maximum number of NFT item's copy or tokens that can be sold.
    function createItem(
        uint256 collectionId,
        string memory itemId,
        address payable _fundingRecipient,
        uint256 _price,
        uint256 _supply
    ) public isAuthorized() isValidated(_fundingRecipient,_supply) {

        _currentItemIndex++;
        emit itemIdPaired(itemId, nextItemId());
        s_itemIdDBToItemId[itemId] = nextItemId();
        Collection memory collection = s_collection[collectionId];
        s_listedItems[address(this)][nextItemId()] = ListedItem({
            nftAddress: address(this),
            numSold: 0,
            royaltyBPS: collection.creatorFee,
            fundingRecipient: _fundingRecipient,
            supply: _supply,
            price: _price,
            itemId: nextItemId(),
            collectionId: collectionId
        });

        emit ItemCreated(
            address(this),
            nextItemId(),
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
    ) public isAuthorized() {
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
    ) public isAuthorized() {
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
    function sendFunds(address payable _recipient, uint256 _amount) public isAuthorized() {
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

    function _burn(uint256 _tokenId)
        internal
        override(ERC721URIStorage)
        onlyOwner
    {
        super._burn(_tokenId);
    }

    function transferNft
    (
        address nftAddress, 
        address creator, 
        address sender, 
        uint256 tokenId
    ) public isAuthorized() 
    {
        IERC721A(nftAddress).safeTransferFrom(creator, sender, tokenId);
    }

    function ownerCheck
    (
        address nftAddress, 
        uint256 tokenId, 
        address sender
    ) public isAuthorized() isOwner(nftAddress, tokenId, sender){
        
    }

}