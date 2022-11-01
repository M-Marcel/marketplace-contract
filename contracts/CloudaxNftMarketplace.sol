// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

////Custom Errors
error InvalidAddress();
error QuantityRequired(uint256 quantity, uint256 minRequired);
error QuantityDoesNotExist(uint256 availableQuantity);
error InvalidItemId(uint256 itemId);
error ItemSoldOut(uint256 quantity, uint256 numSold);
error InsufficientFund(uint256 price, uint256 allowedFund);
error CannotSendFund(uint256 senderBalance, uint256 fundTosend);
error CannotSendZero(uint256 fundTosend);

contract CloudaxNftMarketplace is
    ReentrancyGuard,
    ERC721,
    ERC721URIStorage,
    Ownable
{
    using Counters for Counters.Counter;
    Counters.Counter private tokenId;
    Counters.Counter private listedItemId;

    // structs for an item to be listed
    struct ListedItem {
        uint256 itemId;
        address payable fundingRecipient;
        uint256 price;
        uint32 quantity;
        uint32 numSold;
        uint32 royaltyBPS;
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

    //Mapping of items to a Item struct
    mapping(uint256 => ListedItem) public listedItems;
    ///Mapping an Item to the token copies minted from it.
    mapping(uint256 => uint256) public tokenToListedItem;
    // The amount of funds that have been earned from selling the copies of a given item.
    mapping(uint256 => uint256) public depositedForItem;
    // Total amount earned by Seller... mapping of address -> Amount earned
    mapping(address => uint256) private s_proceeds;
    // mapping(uint256 => uint256) public depositedForEdition;
    string public baseTokenURI;
    string private contractBaseURI;
    uint256 private serviceFee;

    // ================================
    // EVENTS
    // ================================

    ///Emitted when a Item is created
    event ItemCreated(
        uint256 indexed itemId,
        address payable fundingRecipient,
        uint256 numSold,
        uint32 quantity,
        uint32 royaltyBPS
    );

    ///Emitted when a copy of an item is sold
    event itemCopySold(
        uint256 indexed soldItemCopyId,
        uint256 soldItemId,
        uint32 numSold,
        address buyer,
        string soldItemBaseURI
    );

    constructor() ERC721("Cloudax", "CLDX") {
         contractBaseURI = "";
    }

    /// @notice Returns contract URI of an NFT to be used on Opensea. e.g. https://cloudaxnftmarketplace.xyz/metadata/opensea-storefront
    function contractURI() public view returns (string memory) {
        // Concatenate the components, contractBaseURI to create contract URI for Opensea.
        return contractBaseURI;
    }

    // This function is used to update or set the CloudaxNFT Base for Opensea compatibiblity
    function setContractBaseURI(string memory _contractBaseURI) public onlyOwner{
        contractBaseURI = _contractBaseURI;
    }

    // This function is used to update or set the CloudaxNFT Listing price
    function setServiceFee(uint256 _serviceFee) public onlyOwner{
        serviceFee = _serviceFee;
    }

    /// @notice Creates a new NFT item.
    /// @param _fundingRecipient The account that will receive sales revenue.
    /// @param _price The price at which each copy of NFT item or token from a NFT item will be sold, in ETH.
    /// @param _quantity The maximum number of NFT item's copy or tokens that can be sold.
    /// @param _royaltyBPS The royalty amount in bps per copy of a NFT item.
    function createItem(
        address payable _fundingRecipient,
        uint256 _price,
        uint32 _quantity,
        uint32 _royaltyBPS //// onlyOwner
    ) external {
        // Validations
        if (_fundingRecipient == address(0)) {
            revert InvalidAddress();
        }

        // Check that the track's quantity is more than zero(0).
        // require(_quantity > 0, "Track quantity must not be less than 0");
        if (_quantity <= 0) {
            revert QuantityRequired({quantity: _quantity, minRequired: 1});
        }

        listedItemId.increment();
        uint256 newItemId = listedItemId.current();
        listedItems[newItemId] = ListedItem({
            itemId: newItemId,
            fundingRecipient: _fundingRecipient,
            price: _price,
            numSold: 0,
            quantity: _quantity,
            royaltyBPS: _royaltyBPS
        });

        emit ItemCreated(
            newItemId,
            _fundingRecipient,
            0,
            _quantity,
            _royaltyBPS
        );
    }

    /// @notice Creates or mints a new copy or token for the given item, and assigns it to the buyer
    /// @param _itemId The id of the item selected to be purchased
    function buyItemCopy(uint256 _itemId, string memory _tokenBaseURI)
        external
        payable
    {
        // Caching variables locally to reduce reads
        uint256 price = listedItems[_itemId].price;
        uint32 quantity = listedItems[_itemId].quantity;
        uint32 numSold = listedItems[_itemId].numSold;

        // Validations
        // Check that the item's quantity is more than zero(0).
        if (quantity <= 0) {
            revert QuantityDoesNotExist({availableQuantity: quantity});
        }
        // Check that the item's ID is not Zero(0).
        if (_itemId <= 0) {
            revert InvalidItemId({itemId: _itemId});
        }
        // Check that there are still some copies or tokens of the item that are available for purchase.
        if (numSold >= quantity) {
            revert ItemSoldOut({quantity: quantity, numSold: numSold});
        }
        // Check that the buyer approved an amount that is equal or more than the price of the item set by the seller.
        if (price > msg.value) {
            revert InsufficientFund({price: price, allowedFund: msg.value});
        }
        // Update the deposited total for the item.
        // Adding the newly earned money to the total amount a user has earned from an Item.
        depositedForItem[_itemId] += msg.value;

        // Increment the number of copies or tokens sold from this Item.
        listedItems[_itemId].numSold++;
        tokenId.increment();
        uint256 newTokenId = tokenId.current();

        // https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]/[TOKEN_ID]
        // Where _tokenBaseURI = https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
        // Generating a metadata URL for the new copy of the ITEM or Token that was generated.

        _tokenBaseURI = string(
            abi.encodePacked(_tokenBaseURI, "/", Strings.toString(newTokenId))
        );

         // Send funds to the funding recipient.
        _sendFunds(listedItems[_itemId].fundingRecipient, msg.value);
        depositedForItem[_itemId] += msg.value;

        // Mint a new copy or token from the Item for the buyer, using the `newTokenId`.
        safeMint(msg.sender, newTokenId, _tokenBaseURI);
        // Store the mapping of the ID a sold item's copy or token id to the Item being purchased.
        tokenToListedItem[newTokenId] = _itemId;

        emit itemCopySold(
            newTokenId,
            _itemId,
            listedItems[_itemId].numSold,
            msg.sender,
            _tokenBaseURI
        );

    }

    /// @notice Sends funds to an address
    /// @param _recipient The address to send funds to
    /// @param _amount The amount of funds to send
    function _sendFunds(address payable _recipient, uint256 _amount) private {
        if(_amount <= 0){
            revert CannotSendZero({fundTosend: _amount});
        }
        
        (bool success, ) = _recipient.call{value: _amount}('');
        if(!success){
            revert CannotSendFund({senderBalance: address(_recipient).balance, fundTosend: _amount});
        }
    }

    function safeMint(
        address _to,
        uint256 _tokenId,
        string memory _uri
    ) private {
        _safeMint(_to, _tokenId);
        _setTokenURI(_tokenId, _uri);
    }

    /// @notice Returns token metadata URI (metadata URL). e.g. https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        if (!_exists(_tokenId)) {
            revert InvalidItemId({itemId: _tokenId});
        }

        return super.tokenURI(_tokenId);
    }

    // function getPlatformName() public view virtual returns (string memory) {
    //     return _platformName;
    // }

    function _burn(uint256 _tokenId)
        internal
        override(ERC721, ERC721URIStorage)
        onlyOwner
    {
        super._burn(_tokenId);
    }
}