// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface Prot{
    function decimals() external view returns (uint8);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract BuyToken is Ownable{
    Prot prot;
    uint256 priceInUsd; 
    address addr;
    AggregatorV3Interface internal priceFeed;

    // The price of our token is defined by the variable _priceInUsd.
    // Since _priceInUsd is an uint256, this variable can't have 0.001 
    // as a value. That is, in this scenario our new token can´t have 
    // a price less than a usd dollar, unless... we SCALE it.

    // If we scale it by the factor 10^18, we would have 
    // that 0.001 * 10^18 = 10^15 = 1000000000000000 (15 zeros).
    
    // Thus if we set _priceInUsd = 1000000000000000 (15 zeros), it would mean that 
    // we are setting a price of 0.001 usd for our new token.

    // Why 18, because 18 is the number of decimals of our new token.
    
    constructor (address _addr, uint256 _priceInUsd) {
        addr = _addr;
        prot = Prot(_addr);
        priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
        updatePriceInUsd(_priceInUsd);
    }

    // This function will be used for setting the initial price of
    // our new token and for updating futures prices of the token.
    function updatePriceInUsd(uint256 _priceInUsd) public onlyOwner{
        require(_priceInUsd*10**8 >= getLatestPrice(), "Hint, put a price > 10000 (=0.00000000000001 usd)");
        priceInUsd = _priceInUsd;
    }

    // Let webAppNumTokens = 0.1, the number of tokens the user would like
    // to buy.

    // Then the variable webAppNumTokens (=0.1) in the frontend of the  
    // app must be multiply by the factor 10^18.

    // If we scale it by the factor 10^18, we would have 
    // that 0.1 * 10^18 = 10^17 = 100000000000000000 (17 zeros).

    // Thus if we set numTokens = 100000000000000000 (17 zeros) in 
    // our buyToken() function, it would mean that 
    // the user is buying a quantity of 0.1 of our new token.
    
    function buyToken(uint256 numTokens) public payable {
        require(msg.value >= priceInWei()*numTokens, "Not enought money!");
        require(prot.balanceOf(addr) >= numTokens, "Asking more TOKENS than available");
        prot.transfer(msg.sender, numTokens);
    }

    function getAvailableTokens() public view returns(uint256){
        return prot.balanceOf(addr);
    }

    function getLatestPrice() public view returns(uint256){
        (,int latestPrice,,,) = priceFeed.latestRoundData();
        return uint256(latestPrice);
    }

    /*
    1 ETH --> 1*10^18 WEIs --> (latestPrice/18^8)  (1) latestPrice is already multiplied by 10^8
                 x    WEIs --> (priceInUsd/10^18)  (2) priceInUsd is already multiplied by 10^18

    despejando x = priceInUsd * 10^8 / latestPrice
    */
    function priceInWei() public view returns(uint256){
        return (((priceInUsd)*(1*10**8)) / getLatestPrice());
    }

}

// 0xC15099c7c260aF4a77f1541Db3Dd9BfBCAbaF81D

// Examples of input values for the function: updatePriceInUsd() :
// 0.001 usd * 10^18 = 1000000000000000 (15 zeros)
// 0.00000001 usd * 10^18 = 10000000000 (10 zeros)
// 0.00000000000001 usd * 10^18 = 10000 (4 zeros)
