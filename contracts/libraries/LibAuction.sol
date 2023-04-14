// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LibAuction
{
    bytes32 constant AUCTION_STORAGE_POSITION = keccak256("auction.storage");
    bytes32 constant AUCTION_STRUCT_STORAGE_POSITION = keccak256("auction.struct.storage");


    enum 
    AuctionStatus 
    {
        DEFAULT,
        ACTIVE,
        SUCCESSFUL_ENDED,
        UNSUCCESSFULLY_ENDED
    }

    struct Auction {
        uint256 index; // Auction Index
        address addressNFTCollection; // Address of the ERC721 NFT Collection contract
        address addressPaymentToken; // Address of the ERC20 Payment Token contract
        uint256 supply;
        uint256 quantity;
        uint256 startPrice;
        uint256 reservedPrice;
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
        address payable royaltyAddress;
        uint256 royaltyFee;
        uint256 isResell;
        AuctionStatus status;
    }

    struct AuctionStorage {
        IERC20 ERC20Token;
        uint256 SERVICE_FEE; // add services fee

        uint256 _currentAuctionIndex;

        uint256 _currentItemIndex;

        mapping(uint256 => Auction) _idToAuction;
    }

    function auctionStorage() internal pure returns (AuctionStorage storage aas) {
        bytes32 position = AUCTION_STORAGE_POSITION;
        assembly {
            aas.slot := position
        }
    }

    function auctionStruct() internal pure returns (Auction storage astr) {
        bytes32 position = AUCTION_STRUCT_STORAGE_POSITION;
        assembly {
            astr.slot := position
        }
    }

    function _startItemId() internal pure returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the next token ID to be minted.
     */
    function nextItemId() internal view returns (uint256) {
        return auctionStorage()._currentItemIndex;
    }

    // function auctionStructCall() internal pure returns (Auction storage astrcall){
    //    return Auction storage astr = auctionStruct();
    // }

   

}

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// enum AuctionStatus {
//         DEFAULT,
//         ACTIVE,
//         SUCCESSFUL_ENDED,
//         UNSUCCESSFULLY_ENDED
//     }

//     struct Auction {
//         uint256 index; // Auction Index
//         address addressNFTCollection; // Address of the ERC721 NFT Collection contract
//         address addressPaymentToken; // Address of the ERC20 Payment Token contract
//         uint256 supply;
//         uint256 quantity;
//         uint256 startPrice;
//         uint256 reservedPrice;
//         string itemBaseURI;
//         uint256 startTime;
//         uint256 itemId; // NFT Id
//         uint256 tokenId; // tokenId
//         address payable owner; // Creator of the Auction
//         uint256 currentBidPrice; // Current highest bid for the auction
//         uint256 endAuction; // Timestamp for the end day&time of the auction
//         address payable lastBidder;
//         uint256 bidAmount; // Number of bid placed on the auction
//         uint256 duration;
//         address payable royaltyAddress;
//         uint256 royaltyFee;
//         uint256 isResell;
//         AuctionStatus status;
//     }

// struct LibMarketplace{
//     IERC20 ERC20Token;
//     uint256 constant SERVICE_FEE; // add services fee

//     uint256 _currentAuctionIndex;

//     AuctionStatus

//     // Made public for test purposes
//     // IMarketplace marketplace;
//     // Structure to define auction properties

//     mapping(uint256 => Auction) _idToAuction;
// }

// struct AppStorage {
    
//     IERC20 ERC20Token;
//     uint256 constant SERVICE_FEE; // add services fee

//     uint256 _currentAuctionIndex;

//     // Made public for test purposes
//     // IMarketplace marketplace;

//     mapping(uint256 => Auction) _idToAuction;

    
// }