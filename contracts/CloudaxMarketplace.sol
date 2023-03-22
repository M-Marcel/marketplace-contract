// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IMarketplace.sol";



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



contract CloudaxMarketplace is
    ReentrancyGuard,
    ERC721URIStorage,
    Ownable
{
    using SafeMath for uint256;
    IERC20 internal ERC20Token;

    // The next token ID to be minted.
    uint256 internal _currentItemIndex;
    uint256 internal _currentOfferIndex;
    string internal s_contractBaseURI;


    uint256 internal constant SERVICE_FEE = 2;
    uint256 internal s_platformEarning;
    uint256 internal s_totalAmount;
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
        address payable royaltyAddress;
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
        address payable royaltyAddress;
    }

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

    //Mapping of items to a ListedItem struct
    mapping(address => mapping(uint256 => ListedItem)) internal s_listedItems;

    //Mapping of items to a ListedItem struct
    mapping(address => mapping(uint256 => ListedToken)) internal s_listedTokens;

    //Mapping of items to a SoldItem struct
    mapping(address => mapping(uint256 => SoldItem)) internal s_soldItems;

    // webapp itemId(db objectId) to mapping of smart-contract itemId (uint)
    mapping(string => uint256) internal s_itemIdDBToItemId;

    // Total amount earned by Seller... mapping of address -> Amount earned
    mapping(address => uint256) internal s_indivivdualEarningInPlatform;

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
        uint256 time,
        address royaltyAddress
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
        address fundingRecipient
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

    event ItemListingCanceled(address owner, uint256 tokenId, uint256 time);

    event ERC20AddressChanged(address oldAddress, address newAddress);

    event PlatformEarningsWithdrawn(uint256 earnings, address recipient);


    constructor() ERC721A("Cloudax NFTMarketplace", "CLDX") {
        _currentItemIndex = _startItemId();
        ERC20Token = IERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);
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

    modifier isReady(uint256 quantity){
        require(
            quantity >= 1,
            "Must buy atleast one nft"
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
    function nextItemId() internal view virtual returns (uint256) {
        return _currentItemIndex;
    }

    function _currentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    // This function is used to update or set the CloudaxNFT Base for Opensea compatibiblity
    function setContractBaseURI(string memory __contractBaseURI)
        public
        onlyOwner
    {
        s_contractBaseURI = __contractBaseURI;
    }

    function setERC20Token(address newToken) external onlyOwner {
        emit ERC20AddressChanged(address(ERC20Token), newToken);
        ERC20Token = IERC20(newToken);
    }

    // function addPlatformEarning(uint256 amount) public {
    //      s_platformEarning += amount;
    // }

    // function addTotalAmount(uint256 amount) public {
    //      s_totalAmount += amount;
    // }

    /// @notice Creates a new NFT item.
    /// @param _fundingRecipient The account that will receive sales revenue.
    /// @param _price The price at which each copy of NFT item or token from a NFT item will be sold, in ETH.
    /// @param _supply The maximum number of NFT item's copy or tokens that can be sold.
    function _createItem(
        string memory itemId,
        address payable _fundingRecipient,
        uint256 _price,
        uint256 _supply,
        address payable royaltyAddress,
        uint256 royaltyFee
    ) internal isValidated(_fundingRecipient,_supply) {

        _currentItemIndex++;
        emit itemIdPaired(itemId, nextItemId());
        s_itemIdDBToItemId[itemId] = nextItemId();
        s_listedItems[address(this)][nextItemId()] = ListedItem({
            nftAddress: address(this),
            numSold: 0,
            royaltyBPS: royaltyFee,
            fundingRecipient: _fundingRecipient,
            supply: _supply,
            price: _price,
            itemId: nextItemId(),
            royaltyAddress: royaltyAddress
        });

        emit ItemCreated(
            address(this),
            nextItemId(),
            itemId,
            _fundingRecipient,
            _price,
            _supply,
            royaltyFee,
            block.timestamp,
            royaltyAddress
        );
    }

    /// @notice Creates or mints a new copy or token for the given item, and assigns it to the buyer
    /// @param itemId The id of the item selected to be purchased
    function buyItemCopy(
        address payable _fundingRecipient,
        string memory itemId,
        string memory _tokenUri,
        uint256 _price,
        uint256 _qty,
        uint256 _supply,
        address payable royaltyAddress,
        uint256 royaltyFee
    ) public payable nonReentrant 
    isValidated(_fundingRecipient,_supply) 
    isReady(_qty)
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
        uint256 royalty = msg.value.mul(listing.royaltyBPS).div(100);
        uint256 finalAmount = msg.value.sub(serviceFee.add(royalty));


        // Adding the newly earned money to the total amount a user has earned from an Item.
        s_platformEarning += serviceFee;
        s_indivivdualEarningInPlatform[listings.fundingRecipient] += finalAmount;
        s_indivivdualEarningInPlatform[listing.royaltyAddress] += royalty;
        s_totalAmount += msg.value;

        // Send funds to the funding recipient.
        _sendFunds(listings.fundingRecipient, finalAmount);
        if (royalty != 0){
            _sendFunds(listing.royaltyAddress, royalty);
        }
        


        emit ItemCopySold(
            _nextTokenId(),
            _qty,
            listing.royaltyAddress,
            msg.sender,
            finalAmount,
            listing.numSold
        );

        emit ItemCopySold1(
            itemId,
            _tokenUri
        );
        
        
        // Mint a new copy or token from the Item for the buyer
         safeMint(_qty, _tokenUri);
        // Store the mapping of the ID a sold item's copy or token id to the Item being purchased.


        // emit event of item sold, ths also capture the all tokens minted/purshed under a particular item 
        // NB. event is used over the mapping to optimize for gas usage.
        s_soldItems[address(this)][_nextTokenId()] = SoldItem({
            nftAddress: address(this),
            tokenIdFrom: _nextTokenId(),
            quantity: _qty,
            itemId: nextItemId(),
            buyer: payable(msg.sender),
            creator: listings.fundingRecipient,
            itemBaseURI: _tokenUri,
            amountEarned: finalAmount
        });


        s_listedItems[address(this)][nextItemId()] = listing;
    }
    
    function listToken(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        address payable fundingRecipient,
        address payable royaltyAddress,
        uint256 royaltyFee
    ) public isOwner(nftAddress, tokenId, msg.sender) {
        require(
            fundingRecipient == msg.sender,
            "Only the nft owner can receive payment for nft"
        );

        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }

        
        s_listedTokens[nftAddress][tokenId] = ListedToken({
            nftAddress: nftAddress,
            itemId: 0,
            tokenId: tokenId,
            fundingRecipient: fundingRecipient,
            price: price,
            creator: royaltyAddress,
            royaltyBPS: royaltyFee,
            royaltyAddress: royaltyAddress
        });
        address fRecipient = fundingRecipient;

            emit TokenListed
        (
            nftAddress, 
            tokenId, 
            0, 
            msg.sender, 
            price,
            royaltyAddress,
            royaltyFee, 
            block.timestamp,
            fRecipient
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
                listing.fundingRecipient
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
    
        //Deduct the service fee
        uint256 royalty = msg.value.mul(listing.royaltyBPS).div(100);
        uint256 finalAmount = msg.value.sub(serviceFee.add(royalty));

        // Update the deposited total for the item.
        // Adding the newly earned money to the total amount a user has earned from an Item.
        s_indivivdualEarningInPlatform[
            creator
        ] += finalAmount;
        s_platformEarning += serviceFee;
        s_totalAmount += msg.value;

        
        // Send funds to the funding recipient.
        _sendFunds(creator, finalAmount);
        if (royalty != 0){
            _sendFunds(listing.royaltyAddress, royalty);
        }
       

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

        s_listedTokens[nftAddress][tokenId] = listing;

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

    function safeMint(
        uint256 _qty,
        string memory _uri
    ) internal {
        _safeMint(msg.sender, _qty);
        uint256 end = _nextTokenId();
        uint256 index = end - _qty;
        for (uint i = index; i < end; i++) {
            string memory _tURI = string(
                abi.encodePacked(_uri, "/", Strings.toString(i))
            );
            _setTokenURI(i, _tURI);
        }
        
    }

    function safeMintOut(
        uint256 _qty,
        string memory _uri,
        address recipient
    ) internal {
        _safeMint(recipient, _qty);
        uint256 end = _nextTokenId();
        uint256 index = end - _qty;
        for (uint i = index; i < end; i++) {
            string memory _tURI = string(
                abi.encodePacked(_uri, "/", Strings.toString(i))
            );
            _setTokenURI(i, _tURI);
        }
        
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

    function withdrawEarnings(address recipient) external onlyOwner {
        if (s_platformEarning <= 0) {
            revert NoProceeds();
        }

        (bool success, ) = payable(recipient).call{value: s_platformEarning}("");
        if (!success) {
            revert TransferFailed();
        }
        emit PlatformEarningsWithdrawn(s_platformEarning, recipient);
        s_platformEarning = 0;
    }

    // Getter Functions

    /// @notice Returns contract URI of an NFT to be used on Opensea. e.g. https://cloudaxnftmarketplace.xyz/metadata/opensea-storefront
    function getContractURI() public view returns (string memory) {
        // Concatenate the components, s_contractBaseURI to create contract URI for Opensea.
        return s_contractBaseURI;
    }

}