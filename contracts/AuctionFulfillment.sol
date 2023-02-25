// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./CloudaxShared.sol";


contract AuctionFulfillment is
    CloudaxShared
{

    using SafeMath for uint256;

// -----------------------------------VARIABLES-----------------------------------
    // Auction index count
    uint256 internal _currentAuctionIndex;

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

    mapping(uint256 => Auction) internal _idToAuction;
    //Mapping of items to a ListedItem struct
    

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

     enum AuctionStatus {
        DEFAULT,
        ACTIVE,
        SUCCESSFUL_ENDED,
        UNSUCCESSFULLY_ENDED
    }

    constructor() {}

     modifier AuctionIsActive(uint256 auctionId) {
        require(
            _idToAuction[auctionId].status == AuctionStatus.ACTIVE,
            "Auction already ended!"
        );
        _;
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
        uint256 duration
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
        _currentItemIndex++;
        emit itemIdPaired(itemId, _nextItemId());
        s_itemIdDBToItemId[itemId] = _nextItemId();
        Collection memory collection = s_collection[collectionId];
        // s_listedItems[address(this)][_nextItemId()] = ListedItem({
        //     nftAddress: address(this),
        //     numSold: 0,
        //     royaltyBPS: collection.creatorFee,
        //     fundingRecipient: _fundingRecipient,
        //     supply: _supply,
        //     price: startPrice,
        //     itemId: _nextItemId(),
        //     collectionId: collectionId
        // });

        // emit ItemCreated(
        //     address(this),
        //     _nextItemId(),
        //     itemId,
        //     _fundingRecipient,
        //     startPrice,
        //     _supply,
        //     collection.creatorFee,
        //     block.timestamp
        // );

        uint256 day = 1 days;
        uint256 mul_duration = day.mul(duration);

        _currentAuctionIndex++;
        _idToAuction[_currentAuctionIndex] = Auction(
            _currentAuctionIndex,
            address(this),
            address(ERC20Token),
            _supply,
            0,
            startPrice,
            reservedPrice,
            collectionId,
            _tokenUri,
            block.timestamp,
            _nextItemId(),
            0,
            _fundingRecipient,
            0,
            0,
            payable(address(0)),
            0,
            mul_duration,
            AuctionStatus.ACTIVE
        );  


        emit StartAuction(
            _nextAuctionId(), 
            address(this), 
            address(ERC20Token), 
            _supply,
            _nextItemId(),
            msg.sender,
            startPrice,
            reservedPrice,
            block.timestamp,
            mul_duration
        );  
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
            _sendFunds(order.lastBidder, order.currentBidPrice);
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
        uint256 serviceFee = order.currentBidPrice.mul(SERVICE_FEE).div(100);
        uint256 royalty = order.currentBidPrice.mul(collection.creatorFee).div(100);
        uint256 finalAmount = order.currentBidPrice.sub(serviceFee.add(royalty));

  
        s_platformEarning += serviceFee;
        s_totalAmount += finalAmount;
        _sendFunds(order.owner, finalAmount);
        _sendFunds(collection.fundingRecipient, royalty);
        // safeMintOut(1, order.itemBaseURI, _nextItemId(), order.lastBidder); 
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
            _sendFunds(_idToAuction[auctionId].lastBidder, _idToAuction[auctionId].currentBidPrice);
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