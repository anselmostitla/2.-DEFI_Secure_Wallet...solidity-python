// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BuyToken is Ownable{
    IERC20 newToken;
    uint256 priceInUsd; 
    address createTokenAddress;
    AggregatorV3Interface internal priceFeed;

    /*
    What happen if we want to inilialized the price of our newToken
    with 0.001 usd?

    Since the price of our newToken, is defined by the variable _priceInUsd,
    and this an uint256, this variable can't accept 0.001 as a value, 
    it only can accept integer values.

    That is, in this scenario our newToken can´t have a
    price less than a 1 usd dollar, unless... we SCALE it.

    Similar to Ethereum to Wei's..., we can think in a new measure,
    for example dollars to microDollars.

    That is, we can think that 1 Dollar is equivalent to 10^18 microDollars
    (1 dollar = 1,000,000,000,000,000,000 microDollars)

    with this equivalence in mind, if we want to initialize our newToken with
    a price of 0.001 usd.

    It would be enought to scale 0.001  by the factor 10^18, 
    
    if we do the scale or multiplication, we would have that:

    0.001 usd = 0.001 * 10^18 microUsd 
              = 10^15 microUsd
              = 1000000000000000 microUsd (15 zeros).
    
    Thus if we set _priceInUsd = 1000000000000000 (15 zeros), it would mean that 
    we are setting a price of 0.001 usd for our newToken.

    Why 18, because 18 is the number of decimals of our newToken.
     */
    
    constructor(uint256 _priceInUsd, address _createTokenAddress, address _priceFeed) {
        createTokenAddress = _createTokenAddress;
        newToken = IERC20(_createTokenAddress);
        priceFeed = AggregatorV3Interface(_priceFeed);
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

    // Suppose each new Token can be divided into 10^18 equal parts called microTokens.
    // That is 1 Token = 1,000,000,000,000,000,000 microTokens.

    // Then the variable webAppNumTokens (=0.1) in the frontend of the  
    // app must be multiply by the factor 10^18 to get the number of microTokens.

    // If we scale it by the factor 10^18, we would have that 0.1 tokens is equal to
    // 0.1 * 10^18 = 10^17 = 100,000,000,000,000,000 microTokens (17 zeros).

    // Thus if we set numMicroTokens = 100000000000000000 (17 zeros) in 
    // our buyToken() function, it would mean that 
    // the user is buying a quantity of 0.1 Tokens.


    function buyToken(uint256 numMicroTokens) public payable {
        require(msg.value >= priceInWei()*numMicroTokens /(1*10**18), "Not enought money!");
        require(newToken.balanceOf(owner()) >= numMicroTokens, "Asking more TOKENS than available");

        newToken.transferFrom(owner(), msg.sender, numMicroTokens);
    }


    function getAvailableTokens() public view returns(uint256){
        return newToken.balanceOf(owner());
    }
    
    function getLatestPrice() public view returns(uint256){
        (,int latestPrice,,,) = priceFeed.latestRoundData();
        return uint256(latestPrice);
    }

    /*
    1 ETH --> 1*10^18 WEIs --> (latestPrice/10^8)  (1) latestPrice is already multiplied by 10^8
                 x    WEIs --> (priceInUsd/10^18)  (2) priceInUsd is already multiplied by 10^18

    solving for x = priceInUsd * 10^8 / latestPrice
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
