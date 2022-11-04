// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/interfaces/LinkTokenInterface.sol";


interface IStakeToken{
    function interestRate() external;
    
    function getAmountStaked(address _user) external view returns(uint256);

}

contract LendingToken is Ownable{
    IStakeToken stakeToken;
    LinkTokenInterface linkToken;
    AggregatorV3Interface internal priceFeed;   
    AggregatorV3Interface internal priceFeedLinkToken;

    uint256 maxPercentForLending;
    mapping(address => uint256) public lendingOf;
    event eventLendingOf(address indexed _user, uint256 amountBorrowed);


    constructor(address _stakeToken, address _linkToken, address _priceFeed, address _priceFeedLinkToken){
        stakeToken = IStakeToken(_stakeToken);
        linkToken = LinkTokenInterface(_linkToken);
        priceFeed = AggregatorV3Interface(_priceFeed);
        priceFeedLinkToken = AggregatorV3Interface(_priceFeedLinkToken);
    }

    mapping(bytes32 => address) internal contractAddress;

    /*
    collateralCurrency = newToken
    currencyForLending = Link
    */


    function amountOfCurrencyForLending(address _user, uint256 _lendingPercent) public view {
        uint256 microTokensStaked = stakeToken.getAmountStaked(_user);
        require(microTokensStaked > 0, "You don't have newTokens staked");
        uint256 microTokensInLink = convertMicroTokensToLink(microTokensStaked);
        uint256 amountOfLinksForLending = microTokensInLink * _lendingPercent/100;
        linkToken.transfer(_user, amountOfLinksForLending);
        lendingOf[_user] = amountOfLinksForLending;
        emit eventLendingOf(_user, amountOfLinksForLending);
    }

    // For example _maxPercentForLending = 70 (seventy percent)
    function setMaxPercentForLending(uint256 _maxPercentForLending) public onlyOwner{
        maxPercentForLending = _maxPercentForLending;
    }

    function repay(uint256 _amount) public{
        uint256 microTokensStaked = stakeToken.getAmountStaked(msg.sender);
        require(microTokensStaked > 0, "You don't have newTokens staked");
        require(lendingOf[msg.sender] > 0, "You don't have debt in this token");
        require(_amount > 0, "The payment must be positive");
        linkToken.transferFrom(msg.sender, address(this), _amount);
        lendingOf[msg.sender] -= _amount;
        emit eventLendingOf(msg.sender, amountOfLinksForLending);
    }

    function getLatestPrice() public view returns(uint256){
        (,int latestPrice,,,) = priceFeed.latestRoundData();
        return uint256(latestPrice);
    }

    function getTokenLatestPrice(AggregatorV3Interface contractOfSpecificToken) public view returns(uint256){
        (,int latestPrice,,,) = contractOfSpecificToken.latestRoundData();
        return uint256(latestPrice);
    }

    /*
    Since our newToken is not listed on the market, we will simulate the newToken price
    with that of the ethereum divided by 130000. 

    Why the number 130000? Since Ethereum has reached a minimum price of 1,300 aproximately in 2022
    and we want our newToken to begin with 0.01 usd. Thus if we make 1,300/0.01 we get 130,000. 

    1*10^18 microTokens --> ([latestPrice/130000]/10^8)  (1) latestPrice is already multiplied by 10^8
       m    microTokens --> (priceInUsd/10^18)           (2) priceInUsd is already multiplied by 10^18

    Solving for priceInUsd we get:
    
        priceInUsd = (m microTokens) * latestPrice / (10^8 * 130000)

    As a way of testing, the price of one newToken will be 0.01 if we assume that latesPrice = 1300*10^8.
    */
    
    function priceInUsd(uint256 _microTokens) public view returns(uint256){
        return _microTokens*getLatestPrice()/ (130000*10**8);
    }

    /*
    When the user stake certain amount of microTokens, he will be able to borrow Link Tokens say up 
    until a 70% of the microTokens in its equivalent in link tokens.

    1*10^18 microLinks --> (latestPrice/10^8)  (1) latestPrice is already multiplied by 10^8
       m    microLinks --> (priceInUsd/10^18)  (2) priceInUsd is already multiplied by 10^18

    Solving for m microLinks we get:

        m microLinks = 10^8 * priceInUsd / latestPrice

    */
    function priceInLink(uint256 _amountInUsd) public view returns(uint256){
        return 10**8 * _amountInUsd / getTokenLatestPrice(priceFeedLinkToken);
    }

    function convertMicroTokensToLink(uint256 _microTokens) public view returns(uint256){
        uint256 _microTokensInUsd = priceInUsd(_microTokens);
        uint256 _microTokensInLink = priceInLink(_microTokensInUsd);
        return _microTokensInLink;
    }




}