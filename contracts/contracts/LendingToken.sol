// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "../interfaces/LinkTokenInterface.sol";


interface IStakeToken{
    function interestRate() external;
    function getAmountStaked(address _user) external view returns(uint256);
}

contract LendingToken is Ownable{
    IStakeToken stakeToken;
    LinkTokenInterface linkToken;
    AggregatorV3Interface internal priceFeed;   
    AggregatorV3Interface internal priceFeedLinkToken;

    uint256 public maxPercentForLending;
    uint256 public interesRateForDebt;

    mapping(address => uint256) public lendingOf;
    mapping(address => uint256) public timeOfLending;
    event eventLendingOf(address indexed _user, uint256 amountBorrowed);


    constructor(address _stakeToken, address _linkToken, address _priceFeed, address _priceFeedLinkToken, 
                uint256 _interesRateForDebt, uint256 _maxPercentForLending){
        stakeToken = IStakeToken(_stakeToken);
        linkToken = LinkTokenInterface(_linkToken);
        priceFeed = AggregatorV3Interface(_priceFeed);
        priceFeedLinkToken = AggregatorV3Interface(_priceFeedLinkToken);
        setInteresRateForDebt(_interesRateForDebt);
        setMaxPercentForLending(_maxPercentForLending);
    }

    mapping(bytes32 => address) internal contractAddress;

    /*
    collateralCurrency = newToken
    currencyForLending = Link
    */

    function amountOfMicroTokensStaked() public view returns(uint256){
        return stakeToken.getAmountStaked(msg.sender);
    }

    function getAmountOfLending(uint256 _lendingPercent) public view returns(uint256){
        require(_lendingPercent < maxPercentForLending, "Percent for lending set to high");
        uint256 microTokensStaked = amountOfMicroTokensStaked();
        uint256 microTokensInLink = convertMicroTokensToLink(microTokensStaked);
        uint256 amountOfLinksForLending = microTokensInLink * _lendingPercent/10000;
        return amountOfLinksForLending;
    }

    function lendingProcesser(uint256 _lendingPercent) public {
        uint256 amountOfBorrowingToken = getAmountOfLending(_lendingPercent);
        require(amountOfBorrowingToken > 0, "Borrowing amount must greater than zero");
        linkToken.transferFrom(owner(), msg.sender, amountOfBorrowingToken);
        lendingOf[msg.sender] = amountOfBorrowingToken;
        timeOfLending[msg.sender] = block.timestamp;
        emit eventLendingOf(msg.sender, amountOfBorrowingToken);
    }

    // For example _maxPercentForLending = 7000 (seventy percent)
    function setMaxPercentForLending(uint256 _maxPercentForLending) public onlyOwner{
        maxPercentForLending = _maxPercentForLending;
    }


    function repay(uint256 _partialPayment) public{
        // uint256 microTokensStaked = stakeToken.getAmountStaked(msg.sender);
        // require(microTokensStaked > 0, "You don't have newTokens staked");
        uint256 lendingAmount = lendingOf[msg.sender];
        require( lendingAmount > 0, "You don't have debt in this token");

        require(_partialPayment > 0, "The payment must be positive");

        // linkToken.transferFrom(msg.sender, address(this), _partialPayment);
        linkToken.transferFrom(msg.sender, owner(), _partialPayment);
        lendingOf[msg.sender] = lendingAmount + totalDebtCalculationOfLendingCurrency() - _partialPayment;
        timeOfLending[msg.sender] = block.timestamp;
        // emit eventLendingOf(msg.sender, amountOfLinksForLending);
        emit eventLendingOf(msg.sender, lendingOf[msg.sender] );
    }

    // function getTime() public view returns(uint256){
    //     return block.timestamp;
    // }

    // uint256 public currentTime;
    uint256 public totalDebtAmount;
    function totalDebtCalculationOfLendingCurrency() public returns(uint256){
        uint256 initialTime = timeOfLending[msg.sender];
        uint256 currentTime = block.timestamp;
        uint256 deltaTime = (currentTime - initialTime); // 10^5 for taking into account at least one second
        // uint256 _days = deltaTime / (24*60*60);
        uint256 amountOfLending = lendingOf[msg.sender];
        /*
        r: rate of interest
        totalDebt = amountOfLending * (1 + r * _days/360)

        if for example r = 0.0135, that is a 1.35%, we must scale r by the factor 10^4 to include at leat
        two decimal points. Thus if R = r * 10^4, the formula would be:

        totalDebt = amountOfLending * (1 + R * _days/[360*10^4])

        since _days = deltaTime / (24*60*60), we have...

        totalDebt = amountOfLending * (1 + R * [ deltaTime/(24*60*60) ]/[360*10^4])

        // but in the case deltaTime = 1 second, deltaTime/(24*60*60) = 0.000012 which will be rounded to zero.
        // To avoid this, we must scale deltaTime by the factor 10^5 to take into account at leat 5 decimals.
        // Thus the formula will be:

        // totalDebt = amountOfLending * (1*10^5 + R * [ deltaTime*10^5/(24*60*60) ]/[360*10^4])

        // then the result will be given in the scale 10^5, thus in the frontend we must divide the 
        // result by 10^5.

        */

      
        // totalDebtAmount = amountOfLending*(1 + interesRateForDebt * deltaTime/((24*60*60)*(360 * 10**4)));
        totalDebtAmount = amountOfLending * interesRateForDebt * deltaTime/((24*60*60)*(360 * 10**4));
        return totalDebtAmount; 

    }

    // example _interesRateForDebt = 725 (means 7.25%)
    function setInteresRateForDebt(uint256 _interesRateForDebt) public {
        interesRateForDebt = _interesRateForDebt;
    }

    function getLatestPrice() public view returns(uint256){
        (,int latestPrice,,,) = priceFeed.latestRoundData();
        return uint256(latestPrice);
    }


    function getTokenLatestPrice(bool eth) public view returns(uint256){
        int latestPrice;
        if(eth){
            (,latestPrice,,,) = priceFeed.latestRoundData();
        } else{
            (,latestPrice,,,) = priceFeedLinkToken.latestRoundData();
        }
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

    As a way of testing, the price of one newToken will be 0.01 if when latesPrice = 1300*10^8.
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
        // return 10**8 * _amountInUsd / getTokenLatestPrice(priceFeedLinkToken);
        return 10**8 * _amountInUsd / getTokenLatestPrice(false);
    }

    function convertMicroTokensToLink(uint256 _microTokens) public view returns(uint256){
        uint256 _microTokensInUsd = priceInUsd(_microTokens);
        uint256 _microTokensInLink = priceInLink(_microTokensInUsd);
        return _microTokensInLink;
    }




}