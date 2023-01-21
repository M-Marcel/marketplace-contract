// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
// pragma solidity >=0.8.4 <0.9.0;

import "./OrderFulfillment.sol";
import "./AuctionFulfillment.sol";


contract Marketplace is
    OrderFulfillment,
    AuctionFulfillment
{
    /// @notice Returns the CloudaxNFT Listing price
    function getServiceFee() public pure returns (uint256) {
        return SERVICE_FEE;
    }


    function getTokenStatus(uint256 tokenId)
        external
        view
        returns (TokenStatus)
    {
        return s_idToItemStatus[tokenId];
    }

    function getItemsSold() public view returns (uint256) {
        return _nextTokenId();
    }

    function getItemsCreated() public view returns (uint256) {
        return _currentItemIndex;
    }

    function getCollectionCreated() public view returns (uint256) {
        return _currentCollectionIndex;
    }
}