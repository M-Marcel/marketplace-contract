// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;


interface ICloudaxMarketplace {
    function setContractBaseURI(string memory __contractBaseURI) external;

    function setERC20Token(address newToken) external;

    function buyItemCopy(
        address payable _fundingRecipient,
        uint256 collectionId,
        string memory itemId,
        string memory _tokenUri,
        uint256 _price,
        uint256 _qty,
        uint256 _supply
    ) external;

    function listToken(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 collectionId,
        address payable fundingRecipient
    ) external; 

    function updateListing
    (
        address nftAddress, 
        uint256 tokenId, 
        uint256 newPrice
    ) external;

    function cancelListing(address nftAddress, uint256 tokenId) external;

    function createCollection(
        uint256 creatorFee,
        address payable fundingRecipient
    ) external;

    function updateCollection(
        uint256 collectionId,
        uint256 creatorFee,
        address payable fundingRecipient
    ) external;

    function deleteCollection(uint256 collectionId) external; 

    function buyNft(address nftAddress, uint256 tokenId) external;

    function withdrawEarnings() external;
    
}