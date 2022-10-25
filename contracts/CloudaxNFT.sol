// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CloudaxNFT is ERC721, Ownable {
    // ================================
    // STORAGE
    // ================================

    string internal contractBaseURI;

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _contractBaseURI
    ) ERC721(_name, _symbol) {
        // Set ownership to original sender of contract call
        transferOwnership(_owner);

        // E.g.  https://cloudaxnftmarketplace.xyz/metadata/contract/{userId}
        contractBaseURI = _contractBaseURI;
    }

    /// @notice Returns contract URI of an NFT to be used on Opensea. e.g. https://cloudaxnftmarketplace.xyz/metadata/contract/{userId}/storefront
    function contractURI() public view returns (string memory) {
        // Concatenate the components, contractBaseURI to create contract URI for Opensea.
        return string(abi.encodePacked(contractBaseURI, "storefront"));
    }
}
