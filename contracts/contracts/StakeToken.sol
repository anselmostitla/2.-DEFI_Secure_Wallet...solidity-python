// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.6.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakeToken is Pausable, Ownable, ReentrancyGuard {
    IERC20 newToken;
    AggregatorV3Interface internal priceFeed;

    uint16 public interestRate;
    uint256 public minStakingDays;

    uint8 public totalStakers;

    struct StakeInfo {        
        uint256 startTS;
        uint256 endTS;        
        uint256 amount; 
        uint256 stakingDays;
        uint256 trueStakingTime;
        bool claimed;  
        uint256 fee; 
        uint256 interest;   
        uint256 initialPrice; 
        uint256 finalPrice; 
        uint256 finalAmount;
    }
    
    event Staked(address indexed from, uint256 amount);
    event Claimed(address indexed from, uint256 amount);
    
    mapping(address => StakeInfo) public stakeInfos;
    mapping(address => bool) public addressStaked;

    
    constructor(address _tokenAddress, uint16 _interestRate, address _priceFeed, uint256 _minStakingDays) {
        require(address(_tokenAddress) != address(0),"Token Address cannot be address 0");   
        newToken = IERC20(_tokenAddress);
        setInterestRate(_interestRate);
        priceFeed = AggregatorV3Interface(_priceFeed);                   
        totalStakers = 0;
        minStakingDays = _minStakingDays;
    }    


    function getAmountStaked(address _user) public view returns(uint256) {
        return stakeInfos[_user].amount;
    }

    function claimReward(address _to) external returns (bool){
        uint256 currentTime = block.timestamp;
        require(addressStaked[_to] == true, "You are not participated");
        require(stakeInfos[_to].endTS < currentTime, "Stake Time is not over yet");
        require(stakeInfos[_to].claimed == false, "Already claimed");

        stakeInfos[_to].trueStakingTime = currentTime - stakeInfos[_to].startTS;
        stakeInfos[_to].finalPrice = getLatestPrice();
        uint256 stakeAmount = stakeInfos[_to].amount;
        
        uint256 totalTokens = stakeAmount + tokensToPay(_to);
        
        stakeInfos[_to].claimed = true;
        stakeInfos[_to].finalAmount = totalTokens;
        newToken.transfer(_to, totalTokens);
        stakeInfos[_to].amount = 0;

        emit Claimed(_to, totalTokens);

        return true;
    }


    function getTokenExpiry() external view returns (uint256) {
        require(addressStaked[_msgSender()] == true, "You are not participated");
        return stakeInfos[_msgSender()].endTS;
    }


    // stakeAmount must be scale by a factor of 10^18, that is we are working with microTokensToStake
    // function stakeToken(uint256 microTokensToStake, uint256 _stakingDays) external payable whenNotPaused {
    function stakeToken(uint256 microTokensToStake) external payable whenNotPaused {
        require(microTokensToStake >0, "Stake amount should be correct");
        // require(_stakingDays >= minStakingDays , "Staking days must be greaten than min expired");
        // require(addressStaked[_msgSender()] == false, "You already participated");
        
        newToken.transferFrom(_msgSender(), address(this), microTokensToStake);
        totalStakers++;
        addressStaked[_msgSender()] = true;
        uint256 _fee = getFee(microTokensToStake);

        stakeInfos[_msgSender()] = StakeInfo({                
            startTS: block.timestamp,
            endTS: block.timestamp + minStakingDays,
            amount: microTokensToStake,
            // stakingDays: _stakingDays,
            stakingDays: 0,
            trueStakingTime: 0,
            claimed: false,
            fee: _fee,
            interest: interestRate,
            initialPrice: getLatestPrice(),
            finalPrice: getLatestPrice(),
            finalAmount: 0
        });
        
        emit Staked(_msgSender(), microTokensToStake);
    }    

    function increaseStaking(uint256 newMicroTokensToStake) public {
        require(newMicroTokensToStake >0, "Stake amount should be correct");
        require(addressStaked[_msgSender()]);
        // cut previos staking amount and rewards 
        uint256 currentTime = block.timestamp;
        stakeInfos[_msgSender()].trueStakingTime = currentTime - stakeInfos[_msgSender()].startTS;
        stakeInfos[_msgSender()].finalPrice = getLatestPrice();
        uint256 stakeAmount = stakeInfos[_msgSender()].amount;
        uint256 totalTokens = stakeAmount + tokensToPay(_msgSender());
        // add previos amount + rewards + newMicrotokensToStake
        uint256 newAmount = totalTokens + newMicroTokensToStake;
        uint256 _fee = getFee(newAmount);
        newToken.transferFrom(_msgSender(), address(this), newMicroTokensToStake);

        stakeInfos[_msgSender()] = StakeInfo({                
            startTS: block.timestamp,
            endTS: block.timestamp + minStakingDays,
            amount: newAmount,
            // stakingDays: _stakingDays,
            stakingDays: 0,
            trueStakingTime: 0,
            claimed: false,
            fee: _fee,
            interest: interestRate,
            initialPrice: getLatestPrice(),
            finalPrice: getLatestPrice(),
            finalAmount: 0
        });
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getInterestRate() external view returns(uint256) {
            return interestRate;
    } 

    function setInterestRate(uint16 _interestRate) public onlyOwner{
        interestRate = _interestRate;
    }

    function getFee(uint256 amount) internal pure returns(uint256) {
        if (amount < 100 * 10**18) return 1;
        if (amount < 1000 * 10**18) return 10;
        if (amount < 10000 * 10**18) return 20;
        if (amount < 100000 * 10**18) return 30;
        if (amount < 1000000 * 10**18) return 40;
        else return 50;
    }
    

    function getLatestPrice() public view returns(uint256){
        (,int latestPrice,,,) = priceFeed.latestRoundData();
        return uint256(latestPrice);
    }


    function calculationOfTheAmountOfInterest(address _user) internal view returns(uint256){
        uint256 _stakeAmount = stakeInfos[_user].amount;
        uint256 _interestRate = stakeInfos[_user].interest;
        uint256 _trueStakingTime = stakeInfos[_user].trueStakingTime;
        return _stakeAmount * _interestRate * _trueStakingTime / (10000*365*24*60*60);
    }

    /*
    Think a user buys certain AMOUNT of newTokens at a certain _initialPrice in usd.
    Then after 90 days, suppose that such AMOUNT of newTokens is at certain _finalPrice in usd.

    In the scenario where _finalPrice < _initialPrice we have a depretiation.

    In this case, we need to cover the following quantity: _initialPrice - _finalPrice.

    But we need to convert that quantity into our newToken. Thus we have the following
    rule of three.

    AMOUNT of newTokens     --->    _finalPrice
        X  newTokens        --->    _initialPrice - _finalPrice

    Solving for X we have the following formula:

    X = (AMOUNT of newTokens) * (_initialPrice - _finalPrice) / _finalPrice

    */


    /*
    Think a user buys 100 newTokens at 10 usd.
    Then after 90 days, suppose that such 100 newTokens is at 9 usd.

    In this case we have a depretiation.

    In this case, we need to cover the following quantity: 10 usd - 9 usd = 1 usd.

    But we need to convert that quantity into our newToken. Thus we have the following
    rule of three.

    100 newTokens     --->    9 usd
    X  newTokens      --->    1 usd (this quantity is to cover depretiation)

    Solving for X we have the following formula:

    X = (100 newTokens) * (1 usd) / 9 usd

    */
    function tokenCalculationToCoverDepreciation(address _user) public view returns(uint256){
        uint256 _stakeAmount = stakeInfos[_user].amount;
        uint256 _initialPrice = stakeInfos[_user].initialPrice;
        uint256 _finalPrice = stakeInfos[_user].finalPrice;
        return (_stakeAmount*(_initialPrice - _finalPrice))/ _finalPrice;
    }

    function tokensToPay(address _user) internal view returns(uint256){
        uint256 _initialPrice = stakeInfos[_user].initialPrice;
        uint256 _finalPrice = stakeInfos[_user].finalPrice;
        uint256 tokensNeededForDepreciation = tokenCalculationToCoverDepreciation(_user);
        uint256 interestAmount = calculationOfTheAmountOfInterest(_user);
        uint max;
        if (_initialPrice >= _finalPrice){
            if (tokensNeededForDepreciation > interestAmount){
                max = tokensNeededForDepreciation;
            } else {
                max = interestAmount;
            }
        } else {
            max = interestAmount;
        } 
        max -= max * stakeInfos[_user].fee / 1000;
        return max;
    }
    
}

// https://betterprogramming.pub/how-to-write-a-smart-contract-for-stake-the-token-a46fdb9221b6

