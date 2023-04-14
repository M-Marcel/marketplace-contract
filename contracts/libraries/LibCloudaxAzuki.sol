// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/iAzuki.sol";

library LibCloudaxAzuki
{
    bytes32 constant CLOUDAX_AZUKI_STORAGE_POSITION = keccak256("cloudax.azuki.storage");
    bytes32 constant TOKEN_APPROVALREF_STORAGE_POSITION = keccak256("token.approvalRef.storage");

    // Bypass for a `--via-ir` bug (https://github.com/chiru-labs/ERC721A/pull/364).
    struct TokenApprovalRef {
        address value;
    }



    struct CloudaxAzukiStorage {
        // The next token ID to be minted.
        uint256 _currentIndex;

        // The number of tokens burned.
        uint256 _burnCounter;

        // Token name
        string _name;

        // Token symbol
        string _symbol;

        // Mapping from token ID to ownership details
        // An empty struct value does not necessarily mean the token is unowned.
        // See {_packedOwnershipOf} implementation for details.
        //
        // Bits Layout:
        // - [0..159]   `addr`
        // - [160..223] `startTimestamp`
        // - [224]      `burned`
        // - [225]      `nextInitialized`
        // - [232..255] `extraData`
        mapping(uint256 => uint256) _packedOwnerships;

        // Mapping owner address to address data.
        //
        // Bits Layout:
        // - [0..63]    `balance`
        // - [64..127]  `numberMinted`
        // - [128..191] `numberBurned`
        // - [192..255] `aux`
        mapping(address => uint256) _packedAddressData;

        // Mapping from token ID to approved address.
        mapping(uint256 => TokenApprovalRef) _tokenApprovals;

        // Mapping from owner to operator approvals
        mapping(address => mapping(address => bool)) _operatorApprovals;

        // Optional mapping for token URIs
        mapping(uint256 => string) _tokenURIs;


        // =============================================================
        //                           CONSTANTS
        // =============================================================
        // Mask of an entry in packed address data.
        uint256 _BITMASK_ADDRESS_DATA_ENTRY;

        // The bit position of `numberMinted` in packed address data.
        uint256 _BITPOS_NUMBER_MINTED;

        // The bit position of `numberBurned` in packed address data.
        uint256 _BITPOS_NUMBER_BURNED;

        // The bit position of `aux` in packed address data.
        uint256 _BITPOS_AUX;

        // Mask of all 256 bits in packed address data except the 64 bits for `aux`.
        uint256 _BITMASK_AUX_COMPLEMENT;

        // The bit position of `startTimestamp` in packed ownership.
        uint256 _BITPOS_START_TIMESTAMP;

        // The bit mask of the `burned` bit in packed ownership.
        uint256 _BITMASK_BURNED;

        // The bit position of the `nextInitialized` bit in packed ownership.
        uint256 _BITPOS_NEXT_INITIALIZED;

        // The bit mask of the `nextInitialized` bit in packed ownership.
        uint256 _BITMASK_NEXT_INITIALIZED;

        // The bit position of `extraData` in packed ownership.
        uint256 _BITPOS_EXTRA_DATA;

        // Mask of all 256 bits in a packed ownership except the 24 bits for `extraData`.
        uint256 _BITMASK_EXTRA_DATA_COMPLEMENT;

        // The mask of the lower 160 bits for addresses.
        uint256 _BITMASK_ADDRESS;

        // The maximum `quantity` that can be minted with {_mintERC2309}.
        // This limit is to prevent overflows on the address data entries.
        // For a limit of 5000, a total of 3.689e15 calls to {_mintERC2309}
        // is required to cause an overflow, which is unrealistic.
        uint256 _MAX_MINT_ERC2309_QUANTITY_LIMIT;

        // The `Transfer` event signature is given by:
        // `keccak256(bytes("Transfer(address,address,uint256)"))`.
        bytes32 _TRANSFER_EVENT_SIGNATURE;

        // The bit position of `numberMinted` in packed address data.
        // uint256 private constant _BITPOS_NUMBER_MINTED = 64;

        // // The bit position of `numberBurned` in packed address data.
        // uint256 private constant _BITPOS_NUMBER_BURNED = 128;

        // // The bit position of `aux` in packed address data.
        // uint256 private constant _BITPOS_AUX = 192;

        // // Mask of all 256 bits in packed address data except the 64 bits for `aux`.
        // uint256 private constant _BITMASK_AUX_COMPLEMENT = (1 << 192) - 1;

        // // The bit position of `startTimestamp` in packed ownership.
        // uint256 private constant _BITPOS_START_TIMESTAMP = 160;

        // // The bit mask of the `burned` bit in packed ownership.
        // uint256 private constant _BITMASK_BURNED = 1 << 224;

        // // The bit position of the `nextInitialized` bit in packed ownership.
        // uint256 private constant _BITPOS_NEXT_INITIALIZED = 225;

        // // The bit mask of the `nextInitialized` bit in packed ownership.
        // uint256 private constant _BITMASK_NEXT_INITIALIZED = 1 << 225;

        // // The bit position of `extraData` in packed ownership.
        // uint256 private constant _BITPOS_EXTRA_DATA = 232;

        // // Mask of all 256 bits in a packed ownership except the 24 bits for `extraData`.
        // uint256 private constant _BITMASK_EXTRA_DATA_COMPLEMENT = (1 << 232) - 1;

        // // The mask of the lower 160 bits for addresses.
        // uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;

        // // The maximum `quantity` that can be minted with {_mintERC2309}.
        // // This limit is to prevent overflows on the address data entries.
        // // For a limit of 5000, a total of 3.689e15 calls to {_mintERC2309}
        // // is required to cause an overflow, which is unrealistic.
        // uint256 private constant _MAX_MINT_ERC2309_QUANTITY_LIMIT = 5000;

        // // The `Transfer` event signature is given by:
        // // `keccak256(bytes("Transfer(address,address,uint256)"))`.
        // bytes32 private constant _TRANSFER_EVENT_SIGNATURE =
        //     0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    }

    function tokenApprovslRefStorage() internal pure returns (TokenApprovalRef storage taf) {
        bytes32 position = TOKEN_APPROVALREF_STORAGE_POSITION;
        assembly {
            taf.slot := position
        }
    }

    function cloudaxAzukiStorage() internal pure returns (CloudaxAzukiStorage storage cas) {
        bytes32 position = CLOUDAX_AZUKI_STORAGE_POSITION;
        assembly {
            cas.slot := position
        }
    }

    function updateConstants() internal {
        CloudaxAzukiStorage storage cas = cloudaxAzukiStorage();

        // Mask of an entry in packed address data.
        cas._BITMASK_ADDRESS_DATA_ENTRY = (1 << 64) - 1;

        // The bit position of `numberMinted` in packed address data.
        cas._BITPOS_NUMBER_MINTED = 64;

        // The bit position of `numberBurned` in packed address data.
        cas._BITPOS_NUMBER_BURNED = 128;

        // The bit position of `aux` in packed address data.
        cas._BITPOS_AUX = 192;

        // Mask of all 256 bits in packed address data except the 64 bits for `aux`.
        cas._BITMASK_AUX_COMPLEMENT = (1 << 192) - 1;

        // The bit position of `startTimestamp` in packed ownership.
        cas._BITPOS_START_TIMESTAMP = 160;

        // The bit mask of the `burned` bit in packed ownership.
        cas._BITMASK_BURNED = 1 << 224;

        // The bit position of the `nextInitialized` bit in packed ownership.
        cas._BITPOS_NEXT_INITIALIZED = 225;

        // The bit mask of the `nextInitialized` bit in packed ownership.
        cas._BITMASK_NEXT_INITIALIZED = 1 << 225;

        // The bit position of `extraData` in packed ownership.
        cas._BITPOS_EXTRA_DATA = 232;

        // Mask of all 256 bits in a packed ownership except the 24 bits for `extraData`.
        cas._BITMASK_EXTRA_DATA_COMPLEMENT = (1 << 232) - 1;

        // The mask of the lower 160 bits for addresses.
        cas._BITMASK_ADDRESS = (1 << 160) - 1;

        // The maximum `quantity` that can be minted with {_mintERC2309}.
        // This limit is to prevent overflows on the address data entries.
        // For a limit of 5000, a total of 3.689e15 calls to {_mintERC2309}
        // is required to cause an overflow, which is unrealistic.
        cas._MAX_MINT_ERC2309_QUANTITY_LIMIT = 5000;

        // The `Transfer` event signature is given by:
        // `keccak256(bytes("Transfer(address,address,uint256)"))`.
        cas._TRANSFER_EVENT_SIGNATURE =
            0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

        // return cas._BITMASK_ADDRESS_DATA_ENTRY;
    }

}