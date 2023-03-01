// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

// import "../ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";



interface ICloudaxShared {

    function setERC20Token(address newToken) external; 

    function setAuction(address newAddress) external;

    function setMarketplace(address newAddress) external;

    function setOffer(address newAddress) external;

    function nextItemId() external returns (uint256);

    function increaseItemId() external;
     
    function safeMint(
        uint256 _qty,
        string memory _uri,
        uint256 itemId
    ) external;

    function safeMintOut(
        uint256 _qty,
        string memory _uri,
        uint256 itemId,
        address recipient
    ) external;

    function nextCollectionId() external returns (uint256);

    function sendFunds(address payable _recipient, uint256 _amount) external;

    // function tokenURI
    // (
    //     uint256 _tokenId
    // ) external override(ERC721URIStorage) returns (string memory);

    function transferNft
    (
        address nftAddress, 
        address creator, 
        address sender, 
        uint256 tokenId
    ) external;

    function ownerCheck
    (
        address nftAddress, 
        uint256 tokenId, 
        address sender
    ) external;

    function increaseCollectionId() external;

    function getServiceFee() external returns(uint256);

    function getItemsSold() external returns (uint256);

    function getItemsCreated() external returns (uint256); 

    function getCollectionCreated() external returns (uint256);

    function getItemId(string memory itemId) external returns (uint256);

    function setItemId(string memory itemId, uint256 Id) external;

    function setIndivivdualEarningInPlatform(address user, uint256 amount) external;

    function setPlatformEarning(uint256 amount) external;

    function addPlatformEarning(uint256 amount) external;

    function getPlatformEarning() external returns(uint256);

    function setTotalAmount(uint256 amount) external;

    function addTotalAmount(uint256 amount) external;

    function getTotalAmount() external returns(uint256);

    function createItem(
        uint256 collectionId,
        string memory itemId,
        address payable _fundingRecipient,
        uint256 _price,
        uint256 _supply
    ) external;

    function getERC20Token() external returns(IERC20);
}