/*
Dear founders, this is the first smart contract prototype for the project.
I have tested it just on remix. I hope also you can test it on remix.

I am working on a second smart contract so that users can BUY our token.

Also, i am working in a third smart contract so that users can STAKE or LOCK 
their tokens.
*/


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PROTECTION is ERC20, ERC20Burnable, Ownable {

    /*
    This is an example of tokenomics.
    We can define a total supply of 20 million tokens.

    The circulating supply for the first year, for example can be 25%, 
    that is the INITIAL SUPPLY for the first year would be 5 million tokens. 
    And for each subsequent year we can release another 25%.
    */

    uint256 initialSupply = 5000000;
    constructor() ERC20("PROTECTION", "PROT") {
        _mint(address(this), initialSupply * 10 ** decimals());
    }

    // Following the example, for second, third and four years, we 
    // will release another 25% of tokens each year.

    // Then, as this token will be inflationary, from the fitth year 
    // onwards, we will be printing more tokens, for example at an 
    // inflationary rate of 6% each year.

    function mint(uint256 amount) public onlyOwner {
        _mint(address(this), amount);
    }

    // In order to control inflation, we will need to burn certain 
    // rate of tokens year after year.

    function burn(uint256 amount) public virtual override {
        _burn(address(this), amount);
    }

}
