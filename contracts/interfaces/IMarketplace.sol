// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;


interface IMarketplace {

    // This function is used to update or set the CloudaxNFT Base for Opensea compatibiblity
    function setContractBaseURI(string memory __contractBaseURI) external;

    function setERC20Token(address newToken) external;

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
    ) external;
    
    function listToken(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        address payable fundingRecipient,
        address payable royaltyAddress,
        uint256 royaltyFee
    ) external;

    function updateListing
    (
        address nftAddress, 
        uint256 tokenId, 
        uint256 newPrice
    ) external;
       

    function cancelListing(address nftAddress, uint256 tokenId) external;

    function buyNft(address nftAddress, uint256 tokenId) external;

    function tokenURI(uint256 _tokenId) external;

    function withdrawEarnings(address recipient) external;

    function getContractURI() external;

    function nextItemId() external returns (uint256);

    function addPlatformEarning(uint256 amount) external;

    function addTotalAmount(uint256 amount) external;
    
}