// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract CloudaxNFT is Initializable, 
                         ERC721Upgradeable, 
                         OwnableUpgradeable, 
                         UUPSUpgradeable {
    // ================================
    // STORAGE
    // ================================

    string internal contractBaseURI;

function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _contractBaseURI
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init();
        __UUPSUpgradeable_init();
        // Set ownership to original sender of contract call
        transferOwnership(_owner);

        // E.g.  https://cloudaxnftmarketplace.xyz/metadata/contract/{userId}
        contractBaseURI = _contractBaseURI;
    }

    /// @notice Returns contract URI of an NFT to be used on Opensea. e.g. https://cloudaxnftmarketplace.xyz/metadata/contract/{userId}/storefront
    function contractURI() public view returns (string memory) {
        // Concatenate the components, contractBaseURI to create contract URI for Opensea.
        return string(abi.encodePacked(contractBaseURI, 'storefront'));
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
 }