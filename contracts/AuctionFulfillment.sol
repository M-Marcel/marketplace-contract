// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// import "./CloudaxShared.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ICloudaxShared.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ================================
// CUSTOM ERRORS
// ================================
error QuantityRequired(uint256 supply, uint256 minRequired);
error InvalidAddress();


contract AuctionFulfillment is
    ReentrancyGuard,
    Ownable
{

    using SafeMath for uint256;

// -----------------------------------VARIABLES-----------------------------------
    // Auction index count
    uint256 internal _currentAuctionIndex;

    // Made public for test purposes
    ICloudaxShared public cloudaxShared;

     // Structure to define auction properties
    struct Auction {
        uint256 index; // Auction Index
        address addressNFTCollection; // Address of the ERC721 NFT Collection contract
        address addressPaymentToken; // Address of the ERC20 Payment Token contract
        uint256 supply;
        uint256 quantity;
        uint256 startPrice;
        uint256 reservedPrice;
        uint256 collectionId;
        string itemBaseURI;
        uint256 startTime;
        uint256 itemId; // NFT Id
        uint256 tokenId; // tokenId
        address payable owner; // Creator of the Auction
        uint256 currentBidPrice; // Current highest bid for the auction
        uint256 endAuction; // Timestamp for the end day&time of the auction
        address payable lastBidder;
        uint256 bidAmount; // Number of bid placed on the auction
        uint256 duration;
        AuctionStatus status;
    }

    struct Collection{
        address payable fundingRecipient;
        uint256 creatorFee;
        address owner;
    }

    mapping(uint256 => Auction) internal _idToAuction;
    //Mapping of items to a ListedItem struct

    //Mapping of collectionId to a collection struct
    mapping(uint256 => Collection) public s_collection;
    

    event StartAuction(
        uint256 indexed index, // Auction Index
        address indexed nftAddress, // Address of the ERC721 NFT Collection contract
        address addressPaymentToken, // Address of the ERC20 Payment Token contract
        uint256 supply, // NFT Id
        uint256 itemId, // NFT Id
        address seller, // Creator of the item
        uint256 startPrice, // Current offer of the offer
        uint256 reservedPrice, // Number of offers placed on the item
        uint256 listedTime,
        uint256 duration
    );

    event BidIsMade(
        uint256 indexed auctionId,
        uint256 price,
        uint256 numberOfBid,
        address indexed bidder
    );

     event itemIdPaired(string indexed itemIdDB, uint256 indexed itemId);

     event NegativeEndAuction(
        uint256 indexed auctionId,
        address indexed nftAddress,
        address seller,
        uint256 quantity,
        uint256 reservedPrice,
        uint256 lastBid,
        uint256 bidAmount,
        uint256 endTime
    );

    event PositiveEndAuction(
        uint256 indexed auctionId,
        address nftAddress, // Address of the ERC721 NFT Collection contract
        uint256 quantity,
        uint256 reservedPrice,
        uint256 endPrice,
        uint256 bidAmount,
        uint256 endTime,
        address indexed seller,
        address indexed winner
    );

    event EventCanceled(uint256 indexed auctionId, address indexed seller);

    event SharedInterfaceChanged(ICloudaxShared oldAddress, address newAddress);

     enum AuctionStatus {
        DEFAULT,
        ACTIVE,
        SUCCESSFUL_ENDED,
        UNSUCCESSFULLY_ENDED
    }

    constructor(address _cloudaxShared) {
        cloudaxShared = ICloudaxShared(_cloudaxShared);
    }

     modifier AuctionIsActive(uint256 auctionId) {
        require(
            _idToAuction[auctionId].status == AuctionStatus.ACTIVE,
            "Auction already ended!"
        );
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

    /**
     * @dev Returns the starting offer ID.
     * To change the starting offer ID, please override this function.
     */
    function _startAuctionId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the next auction ID to be minted.
     */
    function _nextAuctionId() internal view virtual returns (uint256) {
        return _currentAuctionIndex;
    }

     function listItemOnAuction(
        uint256 collectionId,
        string memory itemId,
        address payable _fundingRecipient,
        string memory _tokenUri,
        uint256 startPrice,
        uint256 reservedPrice,
        uint256 _supply,
        uint256 duration,
        address nftItemAddress,
        uint256 tokenId
        )
        external
        isValidated(_fundingRecipient,_supply)
        /* Adjust enum, remove SOLDOUT, make all listed token ONSELL and everyoter free nft ACTIVE. TokenStatus mapped to nft address mapped to TokenId */
    {

        require(
            _fundingRecipient == msg.sender, 
            "Only nft owner can sell nft"
        );
        require(
            startPrice > 0,
            "Starting price must be greater than zero"
        );
        require(
            reservedPrice >= startPrice,
            "reserved price should not be less than the starting price"
        );
        if(nftItemAddress == address(0))
        {
        cloudaxShared.increaseItemId();
        emit itemIdPaired(itemId, cloudaxShared.nextItemId());
        cloudaxShared.setItemId(itemId, cloudaxShared.nextItemId());
        }

        uint256 day = 1 days;
        uint256 mul_duration = day.mul(duration);
        uint256 startAmount = startPrice;
        uint256 cId = collectionId;
        uint256 rPrice = reservedPrice;
        address fAddress = _fundingRecipient;
        string memory uri = _tokenUri;
        uint256 sply = _supply;
        uint256 dur = mul_duration;

        _currentAuctionIndex++;
        if(nftItemAddress == address(0)){
            _idToAuction[_currentAuctionIndex] = Auction(
                _currentAuctionIndex,
                address(this),
                address(cloudaxShared.getERC20Token()),
                sply,
                0,
                startAmount,
                rPrice,
                cId,
                uri,
                block.timestamp,
                cloudaxShared.nextItemId(),
                0,
                payable(fAddress),
                0,
                0,
                payable(address(0)),
                0,
                dur,
                AuctionStatus.ACTIVE
            );  

            emit StartAuction(
                _nextAuctionId(), 
                address(this), 
                address(cloudaxShared.getERC20Token()), 
                sply,
                cloudaxShared.nextItemId(),
                msg.sender,
                startAmount,
                rPrice,
                block.timestamp,
                dur
            ); 
        }else{
                _idToAuction[_currentAuctionIndex] = Auction(
                    _currentAuctionIndex,
                    nftItemAddress,
                    address(cloudaxShared.getERC20Token()),
                    sply,
                    0,
                    startAmount,
                    rPrice,
                    cId,
                    uri,
                    block.timestamp,
                    0,
                    tokenId,
                    payable(fAddress),
                    0,
                    0,
                    payable(address(0)),
                    0,
                    dur,
                    AuctionStatus.ACTIVE
                );
                emit StartAuction(
                    _nextAuctionId(), 
                    address(this), 
                    address(cloudaxShared.getERC20Token()), 
                    sply,
                    cloudaxShared.nextItemId(),
                    msg.sender,
                    startAmount,
                    rPrice,
                    block.timestamp,
                    dur
                ); 
        }
  
    }

    function makeBid(uint256 quantity, uint256 price, uint256 auctionId)
        payable
        external
        AuctionIsActive(auctionId)
    {
        Auction memory order = _idToAuction[auctionId];

        require(
            price > order.currentBidPrice && price >= order.startPrice,
            "Your bid is less or equal to current bid!"
        );

        require(
            msg.value >= price, "Not enough funds"
        );

        require(
            quantity <= order.supply, 
            "Not enough NFT listed for this auction"
        );

        if (order.bidAmount != 0) {
            // cloudaxShared.sendFunds(order.lastBidder, order.currentBidPrice);
            cloudaxShared.getERC20Token().transfer(order.lastBidder, order.currentBidPrice);
            cloudaxShared.getERC20Token().transferFrom(msg.sender, address(this), price);
        }else{
            cloudaxShared.getERC20Token().transferFrom(msg.sender, address(this), price);
        }

        order.currentBidPrice = price;
        order.lastBidder = payable(msg.sender);
        order.bidAmount += 1;
        order.quantity = quantity;
        _idToAuction[auctionId] = order;

        emit BidIsMade(auctionId, price, order.bidAmount, order.lastBidder);
    }

    

    function finishAuction(uint256 auctionId)
        payable
        external
        AuctionIsActive(auctionId)
        nonReentrant
    {
        Auction memory order = _idToAuction[auctionId];

        require(
            order.startTime + order.duration < block.timestamp,
            "Auction duration not completed!"
        );

        if (order.reservedPrice > order.currentBidPrice) {
            _cancelAuction(auctionId);
            emit NegativeEndAuction(
                auctionId, 
                order.addressNFTCollection,
                order.owner,
                order.quantity,
                order.reservedPrice,
                order.currentBidPrice,
                order.bidAmount,
                block.timestamp
                );
            return;
        }
        Collection memory collection = s_collection[order.collectionId];

        //Deduct the service fee
        uint256 serviceFee = order.currentBidPrice.mul(cloudaxShared.getServiceFee()).div(100);
        uint256 royalty = order.currentBidPrice.mul(collection.creatorFee).div(100);
        uint256 finalAmount = order.currentBidPrice.sub(serviceFee.add(royalty));

  
        cloudaxShared.addPlatformEarning(serviceFee);
        cloudaxShared.addTotalAmount(finalAmount);
        // cloudaxShared.sendFunds(order.owner, finalAmount);
        cloudaxShared.getERC20Token().transfer(order.owner, finalAmount);
        // cloudaxShared.sendFunds(collection.fundingRecipient, royalty);
        cloudaxShared.getERC20Token().transfer(collection.fundingRecipient, royalty);
        if(order.addressNFTCollection == address(this)){
            cloudaxShared.safeMintOut(1, order.itemBaseURI, cloudaxShared.nextItemId(), order.lastBidder); 
        }else{
            cloudaxShared.transferNft(order.addressNFTCollection, order.owner, order.lastBidder, order.tokenId);
        }
        order.status = AuctionStatus.SUCCESSFUL_ENDED;

        emit PositiveEndAuction(
            auctionId,
            order.addressNFTCollection,
            order.quantity,
            order.reservedPrice,
            order.currentBidPrice,
            order.bidAmount,
            block.timestamp,
            order.owner,
            order.lastBidder
        );
    }

    function _cancelAuction(uint256 auctionId) private {
        require(
            _idToAuction[auctionId].status == AuctionStatus.ACTIVE,
            "Auction does not exist"
        );
        _idToAuction[auctionId].status = AuctionStatus.UNSUCCESSFULLY_ENDED;
        if (_idToAuction[auctionId].bidAmount != 0) {
            // cloudaxShared.sendFunds(_idToAuction[auctionId].lastBidder, _idToAuction[auctionId].currentBidPrice);
            cloudaxShared.getERC20Token().transfer(_idToAuction[auctionId].lastBidder, _idToAuction[auctionId].currentBidPrice);
        }
    }

    function cancelAuction(uint256 auctionId) external nonReentrant {
        require(
            msg.sender == _idToAuction[auctionId].owner,
            "You don't have the authority to cancel this auction sale!"
        );
        require(
            _idToAuction[auctionId].bidAmount == 0,
            "You can't cancel the auction which already has a bidder!"
        );
        _cancelAuction(auctionId);
        emit EventCanceled(auctionId, msg.sender);
    }

    function getAuction(uint256 auctionId) public view returns (Auction memory){
        return _idToAuction[auctionId];
    } 
   
}