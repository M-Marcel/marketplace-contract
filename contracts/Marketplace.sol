// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./OrderFulfillment.sol";

contract Marketplace is
    OrderFulfillment
{

    /// @notice Returns the CloudaxNFT Listing price
    function getServiceFee() public pure returns (uint256) {
        return SERVICE_FEE;
    }

    function getItemsSold() public view returns (uint256) {
        return _nextTokenId();
    }

    function getItemsCreated() public view returns (uint256) {
        return _currentItemIndex;
    }

    function withdrawTokens(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(
            recipient != address(0),
            "CLDX: Recipient can't be the zero address"
        );
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        if (amount > balance) {
            amount = balance;
        }
        token.transfer(recipient, amount);
        emit PlatformEarningsWithdrawn(amount, recipient);
    }

}