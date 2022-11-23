// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

////Custom Errors
error InvalidAddress();
error NoProceeds();
error TransferFailed();
error NotOwner();
error QuantityRequired(uint256 quantity, uint256 minRequired);
error QuantityDoesNotExist(uint256 availableQuantity);
error InvalidItemId(uint256 itemId);
error NotListed(uint256 tokenId);
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
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _listedTokenId;
    Counters.Counter private _totalItem;
    Counters.Counter private _totalToken;
    Counters.Counter private _itemsSold;
    Counters.Counter private _itemID;
    string private _contractBaseURI;

    // % times 200 = 2%
    uint256 private _serviceFee = 200;
    uint256 private _platformEarning;
    uint256 private _totalAmount;
    // uint256 public _itemID;
    // Added an additional counter, since _tokenIds can be reduced by burning.
    // And intranal because the marketplace contract will display the total amount.

    // structs for an item to be listed
    struct ListedItem {
        uint256 itemId;
        uint256 tokenId;
        address payable fundingRecipient;
        uint256 price;
        uint32 quantity;
        uint32 numSold;
        uint32 royaltyBPS;
    }

    struct SoldItem {
        uint256 tokenId;
        uint256 itemId;
        address payable buyer;
        address payable creator;
        string tokenBaseURI;
        uint256 amountEarned;
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

    //Mapping of items to a ListedItem struct
    mapping(uint256 => ListedItem) public listedItems;

    //Mapping of items to a SoldItem struct
    mapping(uint256 => SoldItem) public soldItems;

    ///Mapping an Item to the token copies minted from it.
    mapping(uint256 => uint256) public tokenToListedItem;

    // The amount of funds that have been earned from selling the copies of a given item.
    mapping(uint256 => uint256) public depositedForItem;

    // mapping of smart-contract itemId (uint) to webapp itemId(db objectId)
    mapping(uint256 => string) public itemIdToItemId;

    // webapp itemId(db objectId) to mapping of smart-contract itemId (uint)
    mapping(string => uint256) public itemIdDBToItemId;

    // Total amount earned by Seller... mapping of address -> Amount earned
    mapping(address => uint256) private indivivdualEarningInPlatform;

    //Mapping of Item to a TokenStatus struct
    mapping(uint256 => TokenStatus) private _idToItemStatus;

    // mapping(uint256 => uint256) public depositedForEdition;

    // ================================
    // EVENTS
    // ================================

    ///Emitted when a Item is created
    event ItemCreated(
        uint256 indexed itemId,
        string indexed itemIdDB,
        address indexed fundingRecipient,
        uint256 price,
        uint32 quantity,
        uint32 royaltyBPS,
        uint256 time
    );

    ///Emitted when a Item is listed for sell
    event TokenListed(
        uint256 indexed tokenId,
        uint256 indexed itemId,
        address indexed owner,
        uint256 price,
        uint256 time
    );

    ///Emitted when a copy of an item is sold
    event ItemCopySold(
        uint256 indexed soldItemCopyId,
        string indexed soldItemIdDB,
        uint32 numSold,
        address indexed buyer,
        address seller,
        string soldItemBaseURI,
        uint256 amountEarned,
        uint256 time
    );

    ///Emitted when a copy of an item is sold
    event NftItemSold(
        uint256 indexed soldItemCopyId,
        uint256 indexed soldItemId,
        address indexed buyer,
        address seller,
        string soldItemBaseURI,
        uint256 amountEarned,
        uint256 totalAmountEarned,
        uint256 time
    );

    event itemIdPaired(string indexed itemIdDB, uint256 indexed itemId);

    event ServiceFeeUpgraded(uint256 oldFee, uint256 newFee, uint256 time);

    event ItemListingCanceled(address owner, uint256 tokenId, uint256 time);

    enum TokenStatus {
        DEFAULT,
        ACTIVE,
        ONSELL,
        SOLDOUT,
        ONAUCTION,
        BURNED
    }

    constructor() ERC721("Cloudax Marketplace", "CLDX") {
        // _contractBaseURI = "";
    }

    modifier isOwner(address nftAddress, uint256 tokenId, address spender) {
        ERC721 nft = ERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        ListedItem memory listing = listedItems[tokenId];
        if (listing.price <= 0) {
            revert NotListed(tokenId);
        }
        _;
    }

    // This function is used to update or set the CloudaxNFT Base for Opensea compatibiblity
    function setContractBaseURI(string memory __contractBaseURI)
        public
        onlyOwner
    {
        _contractBaseURI = __contractBaseURI;
    }

    // This function is used to update or set the CloudaxNFT Listing price
    function setServiceFee(uint256 __serviceFee) public onlyOwner {
        uint256 oldFee = _serviceFee;
        _serviceFee = __serviceFee;
        emit ServiceFeeUpgraded(oldFee, _serviceFee, block.timestamp);
    }

    /// @notice Creates a new NFT item.
    /// @param _fundingRecipient The account that will receive sales revenue.
    /// @param _price The price at which each copy of NFT item or token from a NFT item will be sold, in ETH.
    /// @param _quantity The maximum number of NFT item's copy or tokens that can be sold.
    /// @param _royaltyBPS The royalty amount in bps per copy of a NFT item.
    function _createItem(
        string memory itemId,
        address payable _fundingRecipient,
        uint256 _price,
        uint32 _quantity,
        uint32 _royaltyBPS //// onlyOwner
    ) private {
        // Validations
        if (_fundingRecipient == address(0)) {
            revert InvalidAddress();
        }

        // Check that the track's quantity is more than zero(0).
        if (_quantity <= 0) {
            revert QuantityRequired({quantity: _quantity, minRequired: 1});
        }

        _itemID.increment();
        uint256 newItemId = _itemID.current();
        itemIdToItemId[newItemId] = itemId;
        itemIdDBToItemId[itemId] = newItemId;
        emit itemIdPaired(itemId, newItemId);

        // _listedTokenId.increment();
        _totalItem.increment();
        listedItems[newItemId] = ListedItem({
            itemId: newItemId,
            tokenId: 0,
            fundingRecipient: _fundingRecipient,
            price: _price,
            numSold: 0,
            quantity: _quantity,
            royaltyBPS: _royaltyBPS
        });

        _idToItemStatus[newItemId] = TokenStatus.ONSELL;

        emit ItemCreated(
            newItemId,
            itemId,
            _fundingRecipient,
            _price,
            _quantity,
            _royaltyBPS,
            block.timestamp
        );
    }

    /// @notice Creates or mints a new copy or token for the given item, and assigns it to the buyer
    /// @param itemId The id of the item selected to be purchased
    function buyItemCopy(
        address payable _fundingRecipient,
        uint256 _price,
        uint32 _quantity,
        uint32 _royaltyBPS,
        string memory itemId,
        string memory _tokenBaseURI
    ) external payable nonReentrant {
        uint256 id = itemIdDBToItemId[itemId];
        if (listedItems[_itemID.current()].itemId != id) {
            _createItem(
                itemId,
                _fundingRecipient,
                _price,
                _quantity,
                _royaltyBPS
            );
        }
        uint256 _itemId = _itemID.current();
        uint256 price = listedItems[_itemId].price;
        uint32 quantity = listedItems[_itemId].quantity;
        if (quantity <= 0 && _itemId <= 0) {
            _createItem(
                itemId,
                _fundingRecipient,
                _price,
                _quantity,
                _royaltyBPS
            );
        }
        _itemId = _itemID.current();

        // 000000000000000000
        // Caching variables locally to reduce reads
        price = listedItems[_itemId].price;
        quantity = listedItems[_itemId].quantity;
        uint256 numSold = listedItems[_itemId].numSold;

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
        if (quantity <= numSold) {
            _idToItemStatus[_itemId] = TokenStatus.SOLDOUT;
            revert ItemSoldOut({quantity: quantity, numSold: numSold});
        }
        // Check that the buyer approved an amount that is equal or more than the price of the item set by the seller.
        if (price > msg.value) {
            revert InsufficientFund({price: price, allowedFund: msg.value});
        }

        // Increment the number of copies or tokens sold from this Item.
        listedItems[_itemId].numSold++;
        _listedTokenId.increment();
        _totalItem.increment();
        uint256 newTokenId = _listedTokenId.current();

        // https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]/[TOKEN_ID]
        // Where _tokenBaseURI = https://cloudaxnftmarketplace.xyz/metadata/[USER_ID]/[ITEM_ID]
        // Generating a metadata URL for the new copy of the ITEM or Token that was generated.

        _tokenBaseURI = string(
            abi.encodePacked(_tokenBaseURI, "/", Strings.toString(newTokenId))
        );

        //Deduct the service fee
        uint256 serviceFee = msg.value.mul(_serviceFee).div(10000);
        uint256 royalty = msg.value.mul(_royaltyBPS).div(100);
        uint256 finalAmount = msg.value.sub(serviceFee + royalty);

        // Update the deposited total for the item.
        // Adding the newly earned money to the total amount a user has earned from an Item.
        depositedForItem[_itemId] += finalAmount;
        indivivdualEarningInPlatform[
            listedItems[_itemId].fundingRecipient
        ] += finalAmount;
        _platformEarning += serviceFee;
        _totalAmount += msg.value;

        // Send funds to the funding recipient.
        _sendFunds(listedItems[_itemId].fundingRecipient, finalAmount);

        // Mint a new copy or token from the Item for the buyer, using the `newTokenId`.
        safeMint(msg.sender, newTokenId, _tokenBaseURI);
        // Store the mapping of the ID a sold item's copy or token id to the Item being purchased.
        tokenToListedItem[newTokenId] = _itemId;

        _idToItemStatus[newTokenId] = TokenStatus.ACTIVE;
        _itemsSold.increment();

        soldItems[newTokenId] = SoldItem({
            tokenId: newTokenId,
            itemId: _itemId,
            buyer: payable(msg.sender),
            creator: listedItems[_itemId].fundingRecipient,
            tokenBaseURI: _tokenBaseURI,
            amountEarned: finalAmount
        });

        emit ItemCopySold(
            newTokenId,
            itemId,
            listedItems[_itemId].numSold,
            msg.sender,
            listedItems[_itemId].fundingRecipient,
            _tokenBaseURI,
            finalAmount,
            block.timestamp
        );
        emit itemIdPaired(itemId, _itemId);
    }

    function listToken(
        address nftAddress
        uint256 tokenId,
        address payable fundingRecipant
    ) public isOwner(nftAddress, tokenId, msg.sender) {
        uint256 itemId = tokenToListedItem[tokenId];
        require(
            fundingRecipant == msg.sender,
            "Only the nft owner can receive"
        );
        ERC721 nft = ERC721(nftAddress);
        nft.approve(address(this), tokenId);
        listedItems[tokenId] = ListedItem({
            itemId: 0,
            tokenId: tokenId,
            fundingRecipient: fundingRecipant,
            price: 0,
            numSold: 0,
            quantity: 0,
            royaltyBPS: 0
        });

        _idToItemStatus[tokenId] = TokenStatus.ONSELL;

        emit TokenListed(tokenId, 0, msg.sender, 0, block.timestamp);
    }

    function cancelListing(address nftAddress, uint256 tokenId)
        external
        isOwner(nftAddress, tokenId, msg.sender)
        isListed(nftAddress, tokenId)
    {
        delete (listedItems[tokenId]);
        emit ItemListingCanceled(msg.sender, tokenId, block.timestamp);
        _idToItemStatus[tokenId] = TokenStatus.ACTIVE;
    }

    /// @notice Creates or mints a new copy or token for the given item, and assigns it to the buyer
    /// @param tokenId The id of the token selected to be purchased
    function buyNft(address nftAddress, uint256 tokenId)
        external
        payable
        isListed(nftAddress, tokenId)
    {
        // Caching variables locally to reduce reads
        uint256 price = listedItems[tokenId].price;
        uint256 itemId = listedItems[tokenId].itemId;


        //Deduct the fees
        uint256 serviceFee = msg.value.mul(_serviceFee).div(10000);
       
        uint256 finalAmount = msg.value.sub(serviceFee);

        // Update the deposited total for the item.
        // Adding the newly earned money to the total amount a user has earned from an Item.
        depositedForItem[itemId] += finalAmount;
        indivivdualEarningInPlatform[
            listedItems[tokenId].fundingRecipient
        ] += finalAmount;
        _platformEarning += serviceFee;
        _totalAmount += msg.value;

        address creator = listedItems[tokenId].fundingRecipient;
        // Send funds to the funding recipient.
        _sendFunds(listedItems[tokenId].fundingRecipient, finalAmount);

        // transfer nft to buyer
        safeTransferFrom(creator, msg.sender, tokenId);

        _idToItemStatus[tokenId] = TokenStatus.ACTIVE;
        _itemsSold.increment();


         soldItems[tokenId] = SoldItem({
            tokenId: tokenId,
            itemId: 0,
            buyer: payable(msg.sender),
            creator: listedItems[_itemId].fundingRecipient,
            tokenBaseURI: _tokenBaseURI,
            amountEarned: finalAmount
        });

        emit ItemCopySold(
            tokenId,
            0,
            0,
            msg.sender,
            listedItems[_itemId].fundingRecipient,
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

    function _burn(uint256 _tokenId)
        internal
        override(ERC721, ERC721URIStorage)
        onlyOwner
    {
        super._burn(_tokenId);
        _totalItem.decrement();
        _idToItemStatus[_tokenId] = TokenStatus.BURNED;
    }

    function withdrawEarnings() external onlyOwner {
        if (_platformEarning <= 0) {
            revert NoProceeds();
        }

        (bool success, ) = payable(msg.sender).call{value: _platformEarning}(
            ""
        );
        if (!success) {
            revert TransferFailed();
        }
        _platformEarning = 0;
    }

    // Getter Functions

    /// @notice Returns contract URI of an NFT to be used on Opensea. e.g. https://cloudaxnftmarketplace.xyz/metadata/opensea-storefront
    function getContractURI() public view returns (string memory) {
        // Concatenate the components, _contractBaseURI to create contract URI for Opensea.
        return _contractBaseURI;
    }

    /// @notice Returns the CloudaxNFT Listing price
    function getServiceFee() public view returns (uint256) {
        return _serviceFee;
    }

    function getTotalAmount() public view returns (uint256) {
        return _totalItem.current();
    }

    function getTokenStatus(uint256 tokenId)
        external
        view
        returns (TokenStatus)
    {
        return _idToItemStatus[tokenId];
    }

    function getItemsSold() public view returns (uint256) {
        return _itemsSold.current();
    }

    function getItemId(uint256 itemId) public view returns (string memory) {
        string memory _itemId = itemIdToItemId[itemId];
        return _itemId;
    }

    function getItemIdDB(string memory itemId) public view returns (uint256) {
        return itemIdDBToItemId[itemId];
    }
}
