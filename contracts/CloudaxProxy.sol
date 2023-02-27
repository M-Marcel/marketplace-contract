// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./interfaces/ICloudaxMarketplace.sol";
import "./interfaces/IAuctionFulfillment.sol";
import "./interfaces/IOrderFulfillment.sol";

//Test params
// www.cloudax.com.metadate/1
// 000000000000000000


contract CloudaxProxy {

    // -----------------------------------VARIABLES-----------------------------------
    address public owner;
    ICloudaxMarketplace public marketplace;
    IAuctionFulfillment public auction;
    IOrderFulfillment public offer;


    constructor(
        address _marketplace,
        address _auction,
        address _offer
    ) {
    marketplace = ICloudaxMarketplace(_marketplace);
    auction = IAuctionFulfillment(_auction);
    offer = IOrderFulfillment(_offer);
  }

// --------------------------MARKETPLACE----------------------------
    function buyItemCopy(
        address payable _fundingRecipient,
        uint256 collectionId,
        string memory itemId,
        string memory _tokenUri,
        uint256 _price,
        uint256 _qty,
        uint256 _supply
    ) public payable{
        (bool success, ) = address(marketplace).delegatecall(
            abi.encodeWithSignature("buyItemCopy(address,uint256,string,string,uint256,uint256,uint256)",
            _fundingRecipient, collectionId, itemId, _tokenUri, _price, _qty, _supply)
        );
        require(success, "buyItemCopy failed");
        }

    function createCollection(
        uint256 creatorFee,
        address payable fundingRecipient
    ) public{
        (bool success, ) = address(marketplace).delegatecall(
            abi.encodeWithSignature("createCollection(uint256,address)", creatorFee, fundingRecipient)
        );
            require(success, "Collection creation failed");
        }

     function listToken(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 collectionId,
        address payable fundingRecipient
    ) external{
        (bool success, ) = address(marketplace).delegatecall(
            abi.encodeWithSignature("listToken(address,uint256,uint256,uint256,address)",
             nftAddress, tokenId, price, collectionId, fundingRecipient)
        );
            require(success, "Token listing failed");
        }

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 collectionId,
        address payable fundingRecipient
    ) external{
        (bool success, ) = address(marketplace).delegatecall(
            abi.encodeWithSignature("updateListing(address,uint256,uint256,uint256,address)",
             nftAddress, tokenId, price, collectionId, fundingRecipient)
        );
            require(success, "Token listing update failed");
        } 

    function cancelListing(address nftAddress, uint256 tokenId)
        external{
        (bool success, ) = address(marketplace).delegatecall(
            abi.encodeWithSignature("updateListing(address,uint256)",
             nftAddress, tokenId)
        );
            require(success, "Token listing cancellation failed");
        } 

// --------------------------Auction----------------------------

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
        external{
        (bool success, ) = address(auction).delegatecall(
            abi.encodeWithSignature("listItemOnAuction(uint256,string,address,string,uint256,uint256,uint256,uint256)", 
            collectionId, itemId, _fundingRecipient, _tokenUri, startPrice, reservedPrice, _supply, duration)
        );
            require(success, "Listing Item on auction failed");
        }

    function makeBid(uint256 quantity, uint256 price, uint256 auctionId)
        payable
        external{
        (bool success, ) = address(auction).delegatecall(
            abi.encodeWithSignature("makeBid(uint256,uint256,uint256)", 
            quantity, price, auctionId)
        );
            require(success, "Bidding failed");
        }

    function finishAuction(uint256 auctionId)
        payable
        external{
        (bool success, ) = address(auction).delegatecall(
            abi.encodeWithSignature("finishAuction(uint256)", 
            auctionId)
        );
            require(success, "Finish auction failed");
        }

    function cancelAuction(uint256 auctionId) 
    external{
        (bool success, ) = address(auction).delegatecall(
            abi.encodeWithSignature("cancelAuction(uint256)", 
            auctionId)
        );
            require(success, "Cancel auction failed");
        }

// --------------------------Offer----------------------------
    function fulfillOfferOrder(
        address payable _fundingRecipient,
        uint256 collectionId,
        string memory itemId,
        string memory _tokenUri,
        uint256 _qty,
        uint256 _supply,
        uint256 offerCount,
        uint256 offerPrice,
        address winnigOfferAddress
    ) external{
        (bool success, ) = address(offer).delegatecall(
            abi.encodeWithSignature("fulfillOfferOrder(address,uint256,string,string,uint256,uint256,uint256,uint256,address)", 
            _fundingRecipient, collectionId, itemId, _tokenUri, _qty, _supply, offerCount, offerPrice,winnigOfferAddress)
        );
            require(success, "Make an offer fulfillment faild");
        }
}
    