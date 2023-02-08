// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
// pragma solidity >=0.8.4 <0.9.0;

import "./CloudaxMarketplace.sol";


contract AuctionFulfillment is
    CloudaxMarketplace
{

    using SafeMath for uint256;

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
        address owner; // Creator of the Auction
        uint256 currentBidPrice; // Current highest bid for the auction
        uint256 endAuction; // Timestamp for the end day&time of the auction
        address lastBidder;
        uint256 bidAmount; // Number of bid placed on the auction
        uint256 duration;
        AuctionStatus status;
    }

        // mapping of auctionId to Auction struct
    mapping(uint256 => Auction) internal _idToAuction;

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
        // isActive(tokenId) 
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
        s_listedItems[address(this)][_nextItemId()] = ListedItem({
            nftAddress: address(this),
            numSold: 0,
            royaltyBPS: collection.creatorFee,
            fundingRecipient: payable(_fundingRecipient),
            supply: _supply,
            price: startPrice,
            itemId: _nextItemId(),
            collectionId: collectionId
        });

        emit ItemCreated(
            address(this),
            _nextItemId(),
            itemId,
            _fundingRecipient,
            startPrice,
            _supply,
            collection.creatorFee,
            block.timestamp
        );

        // address owner = NFT.ownerOf(tokenId);
        // NFT.safeTransferFrom(owner, address(this), tokenId);

        uint256 day = 1 days;
        uint256 mul_duration = day.mul(duration);

        // _idToItemStatus[tokenId] = TokenStatus.ONAUCTION;
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
            (address(0)),
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


    // function listItemOnAuction(
    //     uint256 collectionId,
    //     string memory itemId,
    //     address payable _fundingRecipient,
    //     string memory _tokenUri,
    //     address nftAddress,
    //     uint256 tokenId,
    //     uint256 startPrice,
    //     uint256 reservedPrice,
    //     uint256 _supply,
    //     uint256 duration,
    //     bool resell
    // )
    //     external
    //     isValidated(_fundingRecipient,_supply)
    //     // isActive(tokenId) 
    //     /* Adjust enum, remove SOLDOUT, make all listed token ONSELL and everyoter free nft ACTIVE. TokenStatus mapped to nft address mapped to TokenId */
    // {

    //     require(
    //         _fundingRecipient == msg.sender, 
    //         "Only nft owner can sell nft"
    //     );
    //     require(
    //         startPrice > 0,
    //         "Starting price must be greater than zero"
    //     );
    //     require(
    //         reservedPrice >= startPrice,
    //         "reserved price should not be less than the starting price"
    //     );
    //     _currentItemIndex++;
    //     emit itemIdPaired(itemId, _nextItemId());
    //     s_itemIdDBToItemId[itemId] = _nextItemId();
    //     Collection memory collection = s_collection[collectionId];
    //     uint256 day = 1 days;
    //     uint256 mul_duration = day.mul(duration);

    //     if(resell){
    //         if (nftAddress == address(this)){
    //             s_listedTokens[nftAddress][tokenId] = ListedToken({
    //                 nftAddress: nftAddress,
    //                 itemId: 0,
    //                 tokenId: tokenId,
    //                 fundingRecipient: _fundingRecipient,
    //                 price: startPrice,
    //                 creator: collection.fundingRecipient,
    //                 royaltyBPS: collection.creatorFee,
    //                 collectionId: collectionId
    //             });
    //             _currentAuctionIndex++;
    //             _idToAuction[_currentAuctionIndex] = Auction(
    //                 _currentAuctionIndex,
    //                 address(this),
    //                 address(ERC20Token),
    //                 _supply,
    //                 0,
    //                 startPrice,
    //                 reservedPrice,
    //                 collectionId,
    //                 "",
    //                 block.timestamp,
    //                 _nextItemId(),
    //                 tokenId,
    //                 _fundingRecipient,
    //                 0,
    //                 0,
    //                 (address(0)),
    //                 0,
    //                 mul_duration,
    //                 AuctionStatus.ACTIVE
    //             );

    //                 emit TokenListed
    //             (
    //                 nftAddress, 
    //                 tokenId, 
    //                 0, 
    //                 msg.sender, 
    //                 startPrice,
    //                 collection.fundingRecipient,
    //                 collection.creatorFee, 
    //                 block.timestamp,
    //                 collectionId
    //             );
    //         }else{
    //             s_listedTokens[nftAddress][tokenId] = ListedToken({
    //                 nftAddress: nftAddress,
    //                 itemId: 0,
    //                 tokenId: tokenId,
    //                 fundingRecipient: _fundingRecipient,
    //                 price: startPrice,
    //                 creator: address(0),
    //                 royaltyBPS: 0,
    //                 collectionId: 0
    //             });

    //             _currentAuctionIndex++;
    //             _idToAuction[_currentAuctionIndex] = Auction(
    //                 _currentAuctionIndex,
    //                 nftAddress,
    //                 address(ERC20Token),
    //                 _supply,
    //                 0,
    //                 startPrice,
    //                 reservedPrice,
    //                 collectionId,
    //                 "",
    //                 block.timestamp,
    //                 _nextItemId(),
    //                 tokenId,
    //                 _fundingRecipient,
    //                 0,
    //                 0,
    //                 (address(0)),
    //                 0,
    //                 mul_duration,
    //                 AuctionStatus.ACTIVE
    //             );
    //             emit TokenListed
    //             (
    //                 nftAddress, 
    //                 tokenId, 
    //                 0, 
    //                 msg.sender, 
    //                 startPrice,
    //                 collection.fundingRecipient,
    //                 collection.creatorFee, 
    //                 block.timestamp,
    //                 collectionId
    //             );
    //         }     
    //     }else{

    //         s_listedItems[address(this)][_nextItemId()] = ListedItem({
    //             nftAddress: address(this),
    //             numSold: 0,
    //             royaltyBPS: collection.creatorFee,
    //             fundingRecipient: payable(_fundingRecipient),
    //             supply: _supply,
    //             price: startPrice,
    //             itemId: _nextItemId(),
    //             collectionId: collectionId
    //         });

    //         emit ItemCreated(
    //             address(this),
    //             _nextItemId(),
    //             itemId,
    //             _fundingRecipient,
    //             startPrice,
    //             _supply,
    //             collection.creatorFee,
    //             block.timestamp
    //         );

    //         // address owner = NFT.ownerOf(tokenId);
    //         // NFT.safeTransferFrom(owner, address(this), tokenId);

    //         // _idToItemStatus[tokenId] = TokenStatus.ONAUCTION;
    //         _currentAuctionIndex++;
    //         _idToAuction[_currentAuctionIndex] = Auction(
    //             _currentAuctionIndex,
    //             address(this),
    //             address(ERC20Token),
    //             _supply,
    //             0,
    //             startPrice,
    //             reservedPrice,
    //             collectionId,
    //             _tokenUri,
    //             block.timestamp,
    //             _nextItemId(),
    //             0,
    //             _fundingRecipient,
    //             0,
    //             0,
    //             (address(0)),
    //             0,
    //             mul_duration,
    //             AuctionStatus.ACTIVE
    //         );  
    //     }

    //     emit StartAuction(
    //         _nextAuctionId(), 
    //         address(this), 
    //         address(ERC20Token), 
    //         _supply,
    //         _nextItemId(),
    //         msg.sender,
    //         startPrice,
    //         reservedPrice,
    //         block.timestamp,
    //         mul_duration
    //     );  
    // }


    // function listItemOnAuctionResell(
    //     uint256 collectionId,
    //     string memory itemId,
    //     address payable _fundingRecipient,
    //     address nftAddress,
    //     uint256 tokenId,
    //     uint256 startPrice,
    //     uint256 reservedPrice,
    //     uint256 _supply,
    //     uint256 duration
    //     )
    //     external
    //     isValidated(_fundingRecipient,_supply)
    //     // isActive(tokenId) 
    //     /* Adjust enum, remove SOLDOUT, make all listed token ONSELL and everyoter free nft ACTIVE. TokenStatus mapped to nft address mapped to TokenId */
    // {

    //     require(
    //         _fundingRecipient == msg.sender, 
    //         "Only nft owner can sell nft"
    //     );
    //     require(
    //         startPrice > 0,
    //         "Starting price must be greater than zero"
    //     );
    //     require(
    //         reservedPrice >= startPrice,
    //         "reserved price should not be less than the starting price"
    //     );
    //     _currentItemIndex++;
    //     emit itemIdPaired(itemId, _nextItemId());
    //     s_itemIdDBToItemId[itemId] = _nextItemId();
    //     Collection memory collection = s_collection[collectionId];
    //     uint256 day = 1 days;
    //     uint256 mul_duration = day.mul(duration);

    //    if (nftAddress == address(this)){
    //         s_listedTokens[nftAddress][tokenId] = ListedToken({
    //             nftAddress: nftAddress,
    //             itemId: 0,
    //             tokenId: tokenId,
    //             fundingRecipient: _fundingRecipient,
    //             price: startPrice,
    //             creator: collection.fundingRecipient,
    //             royaltyBPS: collection.creatorFee,
    //             collectionId: collectionId
    //         });

    //         _idToAuction[_currentAuctionIndex] = Auction(
    //             _currentAuctionIndex,
    //             address(this),
    //             address(ERC20Token),
    //             _supply,
    //             0,
    //             startPrice,
    //             reservedPrice,
    //             collectionId,
    //             "",
    //             block.timestamp,
    //             _nextItemId(),
    //             tokenId,
    //             _fundingRecipient,
    //             0,
    //             0,
    //             payable(address(0)),
    //             0,
    //             mul_duration,
    //             AuctionStatus.ACTIVE
    //         );

    //             emit TokenListed
    //         (
    //             nftAddress, 
    //             tokenId, 
    //             0, 
    //             msg.sender, 
    //             startPrice,
    //             collection.fundingRecipient,
    //             collection.creatorFee, 
    //             block.timestamp,
    //             collectionId
    //         );
    //     }else{
    //         s_listedTokens[nftAddress][tokenId] = ListedToken({
    //         nftAddress: nftAddress,
    //         itemId: 0,
    //         tokenId: tokenId,
    //         fundingRecipient: _fundingRecipient,
    //         price: startPrice,
    //         creator: address(0),
    //         royaltyBPS: 0,
    //         collectionId: 0
    //     });
    //         emit TokenListed
    //         (
    //             nftAddress, 
    //             tokenId, 
    //             0, 
    //             msg.sender, 
    //             startPrice,
    //             collection.fundingRecipient,
    //             collection.creatorFee, 
    //             block.timestamp,
    //             collectionId
    //         );
    //     }

        

    //     // address owner = NFT.ownerOf(tokenId);
    //     // NFT.safeTransferFrom(owner, address(this), tokenId);

       

    //     // _idToItemStatus[tokenId] = TokenStatus.ONAUCTION;
    //     _currentAuctionIndex++;
    //     _idToAuction[_currentAuctionIndex] = Auction(
    //         _currentAuctionIndex,
    //         address(this),
    //         address(ERC20Token),
    //         _supply,
    //         0,
    //         startPrice,
    //         reservedPrice,
    //         collectionId,
    //         "",
    //         block.timestamp,
    //         _nextItemId(),
    //         tokenId,
    //         _fundingRecipient,
    //         0,
    //         0,
    //         payable(address(0)),
    //         0,
    //         mul_duration,
    //         AuctionStatus.ACTIVE
    //     );  

    //     emit StartAuction(
    //         _nextAuctionId(), 
    //         address(this), 
    //         address(ERC20Token), 
    //         _supply,
    //         _nextItemId(),
    //         msg.sender,
    //         startPrice,
    //         reservedPrice,
    //         block.timestamp,
    //         mul_duration
    //     );  
    // }

    function makeBid(uint256 quantity, uint256 price, uint256 auctionId)
        external
        AuctionIsActive(auctionId)
    {
        Auction memory order = _idToAuction[auctionId];

        require(
            price > order.currentBidPrice && price >= order.startPrice,
            "Your bid is less or equal to current bid!"
        );

        require(
            quantity <= order.supply, 
            "Not enough NFT listed for this auction"
        );

        if (order.startPrice != 0) {
            if(ERC20Token.transfer(order.lastBidder, order.currentBidPrice) == !true){
                revert TransferNotCompleted({
                    senderBalance: ERC20Token.balanceOf(order.lastBidder),
                    fundTosend: order.currentBidPrice
                });
            }     
        }

        if(ERC20Token.transferFrom(msg.sender, address(this), price) == !true){
            revert TransferNotCompleted({
                senderBalance: ERC20Token.balanceOf(msg.sender),
                fundTosend: price
            });
        }

        order.currentBidPrice = price;
        order.lastBidder = msg.sender;
        order.bidAmount += 1;
        order.quantity = quantity;
        _idToAuction[auctionId] = order;

        emit BidIsMade(auctionId, price, order.bidAmount, order.lastBidder);
    }

    function finishAuction(uint256 auctionId)
        external
        AuctionIsActive(auctionId)
        nonReentrant
    {
        Auction memory order = _idToAuction[auctionId];

        require(
            order.startTime + order.duration < _currentTime(),
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

        // order.itemBaseURI

        // NFT.safeTransferFrom(address(this), order.lastBidder, tokenId);

        //Deduct the service fee
        uint256 serviceFee = order.currentBidPrice.mul(SERVICE_FEE).div(100);
        uint256 royalty = order.currentBidPrice.mul(collection.creatorFee).div(100);
        uint256 finalAmount = order.currentBidPrice.sub(serviceFee.add(royalty));


        // Adding the newly earned money to the total amount a user has earned from an Item.
        s_depositedForItem[_nextItemId()] += finalAmount; // optmize
        s_platformEarning += serviceFee;
        s_indivivdualEarningInPlatform[order.owner] += finalAmount;
        s_indivivdualEarningInPlatform[collection.fundingRecipient] += royalty;
        s_totalAmount += finalAmount;

        if(ERC20Token.transfer(order.owner, finalAmount) == !true){
            revert TransferNotCompleted({
                senderBalance: ERC20Token.balanceOf(order.owner),
                fundTosend: order.currentBidPrice
            });
        }

        if(ERC20Token.transfer(collection.fundingRecipient, royalty) == !true){
            revert TransferNotCompleted({
                senderBalance: ERC20Token.balanceOf(address(this)),
                fundTosend: royalty
            });
        }

        // Mint a new copy or token from the Item for the buyer
         safeMint(1, order.itemBaseURI, _nextItemId()); 

        order.status = AuctionStatus.SUCCESSFUL_ENDED;
        // _idToItemStatus[tokenId] = TokenStatus.ACTIVE;

        // _itemsSold.increment();
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

    // function finishAuctionResell(uint256 auctionId)
    //     external
    //     AuctionIsActive(auctionId)
    //     nonReentrant
    // {
    //     Auction memory order = _idToAuction[auctionId];

    //     require(
    //         order.startTime + order.duration < _currentTime(),
    //         "Auction duration not completed!"
    //     );

    //     if (order.reservedPrice > order.currentBidPrice) {
    //         _cancelAuction(auctionId);
    //         emit NegativeEndAuction(
    //             auctionId, 
    //             order.addressNFTCollection,
    //             order.owner,
    //             order.quantity,
    //             order.reservedPrice,
    //             order.currentBidPrice,
    //             order.bidAmount,
    //             block.timestamp
    //             );
    //         return;
    //     }

    //     Collection memory collection = s_collection[order.collectionId];

    //     // order.itemBaseURI

    //     // NFT.safeTransferFrom(address(this), order.lastBidder, tokenId);

    //     //Deduct the service fee
    //     uint256 serviceFee = order.currentBidPrice.mul(SERVICE_FEE).div(100);
    //     uint256 royalty = order.currentBidPrice.mul(collection.creatorFee).div(100);
    //     uint256 finalAmount = order.currentBidPrice.sub(serviceFee.add(royalty));


    //     // Adding the newly earned money to the total amount a user has earned from an Item.
    //     s_depositedForItem[_nextItemId()] += finalAmount; // optmize
    //     s_platformEarning += serviceFee;
    //     s_indivivdualEarningInPlatform[order.owner] += finalAmount;
    //     s_indivivdualEarningInPlatform[collection.fundingRecipient] += royalty;
    //     s_totalAmount += finalAmount;

    //     if(ERC20Token.transfer(order.owner, order.currentBidPrice) == !true){
    //         revert TransferNotCompleted({
    //             senderBalance: ERC20Token.balanceOf(order.owner),
    //             fundTosend: order.currentBidPrice
    //         });
    //     }

    //     if(ERC20Token.transfer(collection.fundingRecipient, royalty) == !true){
    //         revert TransferNotCompleted({
    //             senderBalance: ERC20Token.balanceOf(address(this)),
    //             fundTosend: royalty
    //         });
    //     }

    //     // Mint a new copy or token from the Item for the buyer
    //      safeMint(1, order.itemBaseURI, _nextItemId()); 

    //     order.status = AuctionStatus.SUCCESSFUL_ENDED;
    //     // _idToItemStatus[tokenId] = TokenStatus.ACTIVE;

    //     // _itemsSold.increment();
    //     emit PositiveEndAuction(
    //         auctionId,
    //         order.addressNFTCollection,
    //         order.quantity,
    //         order.reservedPrice,
    //         order.currentBidPrice,
    //         order.bidAmount,
    //         block.timestamp,
    //         order.owner,
    //         order.lastBidder
    //     );
    // }

    function _cancelAuction(uint256 auctionId) private {
        _idToAuction[auctionId].status = AuctionStatus.UNSUCCESSFULLY_ENDED;

        // NFT.safeTransferFrom(
        //     address(this),
        //     _idToAuctionOrder[tokenId].owner,
        //     tokenId
        // );
        // _idToItemStatus[tokenId] = TokenStatus.ACTIVE;

        if (_idToAuction[auctionId].bidAmount != 0) {
            ERC20Token.transfer(
                _idToAuction[auctionId].lastBidder,
                _idToAuction[auctionId].currentBidPrice
            );
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
    
}