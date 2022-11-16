// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LinkToken is ERC20, ERC20Burnable, Ownable {
    /*
    This is an example of tokenomics.
    We can define a total supply of 20 million tokens.

    The circulating supply for the first year, for example can be 25%, 
    that is the INITIAL SUPPLY for the first year would be 5 million tokens. 
    And for each subsequent year we can release another 25%.
    */

    uint256 initialSupply = 5000000;

    constructor() ERC20("ChainLink Token", "LINK") {
        // _mint(address(this), initialSupply * 10**decimals());
        _mint(msg.sender, initialSupply * 10**decimals());
    }
}