// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ================================
// CUSTOM ERRORS
// ================================
error QuantityRequired(uint256 supply, uint256 minRequired);
error InvalidAddress();
error CannotSendFund(uint256 senderBalance, uint256 fundTosend);
error CannotSendZero(uint256 fundTosend);


contract CloudaxShared is
    ReentrancyGuard,
    ERC721URIStorage,
    Ownable
{

    using SafeMath for uint256;
    IERC20 internal ERC20Token;


    // The next token ID to be minted.
    uint256 internal _currentItemIndex;
    uint256 internal _currentCollectionIndex;
    // % times 200 = 2%
    uint256 internal constant SERVICE_FEE = 2;
    uint256 internal constant auction = 2;
    uint256 internal s_platformEarning;
    uint256 internal s_totalAmount;

    // ================================
    // STRUCTS
    // ================================
    struct Collection{
        address payable fundingRecipient;
        uint256 creatorFee;
        address owner;
    }

    // webapp itemId(db objectId) to mapping of smart-contract itemId (uint)
    mapping(string => uint256) public s_itemIdDBToItemId;

    // Total amount earned by Seller... mapping of address -> Amount earned
    mapping(address => uint256) internal s_indivivdualEarningInPlatform;

    //Mapping of collectionId to a collection struct
    mapping(uint256 => Collection) public s_collection;

    // mapping of collection to item to TokenId
    mapping(uint256 => mapping(uint256 => uint256)) public s_tokensToItemToCollection;


    // ================================
    // EVENTS
    // ================================
    ///Emitted when a Item is created
    event ItemCreated(
        address nftAddress,
        uint256 indexed itemId,
        string indexed itemIdDB,
        address indexed fundingRecipient,
        uint256 price,
        uint256 supply,
        uint256 royaltyBPS,
        uint256 time
    );

    //Emitted when a collection is created
    event CollectionCreated(
        uint256 collectionId,
        address indexed fundingRecipient,
        uint256 creatorFee,
        address indexed owner,
        uint256 time
    );

    //Emitted when a collection is created
    event CollectionUpdated(
        uint256 collectionId,
        address indexed fundingRecipient,
        uint256 creatorFee,
        address indexed owner,
        uint256 time
    );
    
    event itemIdPaired(string indexed itemIdDB, uint256 indexed itemId);

    event CollectionDeleted(address owner, uint256 collectionId, uint256 time);

    event ERC20AddressChanged(address oldAddress, address newAddress);


    constructor() ERC721A("Cloudax NFTMarketplace", "CLDX"){}

    // ================================
    // MODIFIERS
    // ================================
    modifier isValidated(address fundingRecipient,uint256 supply){
        if (fundingRecipient == address(0)) {
            revert InvalidAddress();
        }
        // Check that the track's supply is more than zero(0).
        if (supply <= 0) {
            revert QuantityRequired({supply: supply, minRequired: 1});
        }
        _;
    }

    /**
     * @dev Returns the starting token ID.
     * To change the starting token ID, please override this function.
     */
    function _startItemId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the next token ID to be minted.
     */
    function _nextItemId() internal view virtual returns (uint256) {
        return _currentItemIndex;
    }

    /**
     * @dev Returns the starting collection ID.
     * To change the starting collection ID, please override this function.
     */
    function _startCollectionId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the next collection ID to be minted.
     */
    function _nextCollectionId() internal view virtual returns (uint256) {
        return _currentCollectionIndex;
    }

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

    function getCollectionCreated() public view returns (uint256) {
        return _currentCollectionIndex;
    }

    /// @notice Sends funds to an address
    /// @param _recipient The address to send funds to
    /// @param _amount The amount of funds to send
    function _sendFunds(address payable _recipient, uint256 _amount) internal {
        if (_amount <= 0) {
            revert CannotSendZero({fundTosend: _amount});
        }

        (bool success, ) = _recipient.call{value: _amount}("");
        if (!success) {
            revert CannotSendFund({
                senderBalance: address(_recipient).balance,
                fundTosend: _amount
            });
        }
    }  

}