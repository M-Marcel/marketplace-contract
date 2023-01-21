// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @custom:security-contact marhandrez@gmail.com
contract wETH is ERC20 {
    constructor() ERC20("wEth", "TWETH") {
        _mint(msg.sender, 10000000000 * 10 ** decimals());
    }
}