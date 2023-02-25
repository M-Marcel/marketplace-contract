// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;


interface IAuctionFulfillment {
    function listItemOnAuction(
        uint256 collectionId,
        string memory itemId,
        address payable _fundingRecipient,
        string memory _tokenUri,
        uint256 startPrice,
        uint256 reservedPrice,
        uint256 _supply,
        uint256 duration
    ) external;

    function makeBid(uint256 quantity, uint256 price, uint256 auctionId) external;

    function finishAuction(uint256 auctionId) external;

    function cancelAuction(uint256 auctionId) external;
}