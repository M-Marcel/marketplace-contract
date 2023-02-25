// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IOrderFulfillment {
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
    ) external;
}