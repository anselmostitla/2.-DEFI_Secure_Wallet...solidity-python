// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.6.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface Token {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (uint256);    
    function approve(address spender, uint256 amount) external returns (bool);
    function owner() external view returns (address);
}

contract StakeToken is Pausable, Ownable, ReentrancyGuard {
    IERC20 myToken;
    Token newToken;
    AggregatorV3Interface internal priceFeed;
    
    // 180 Days (180 * 24 * 60 * 60)
    uint256 _planExpired = 15552000;

    uint16 public interestRate;

    uint256 public planExpired;
    uint8 public totalStakers;

    struct StakeInfo {        
        uint256 startTS;
        uint256 endTS;        
        uint256 amount; 
        uint256 stakingDays;
        uint256 claimed;   
        uint256 interest;   
        uint256 initialPrice; 
        uint256 finalPrice; 
    }
    
    event Staked(address indexed from, uint256 amount);
    event Claimed(address indexed from, uint256 amount);
    
    mapping(address => StakeInfo) public stakeInfos;
    mapping(address => bool) public addressStaked;

    
    constructor(address _tokenAddress, uint16 _interestRate, address _priceFeed) {
        require(address(_tokenAddress) != address(0),"Token Address cannot be address 0");   
        newToken = Token(_tokenAddress);
        myToken = IERC20(_tokenAddress);
        setInterestRate(_interestRate);
        priceFeed = AggregatorV3Interface(_priceFeed);                   
        planExpired = block.timestamp + _planExpired;
        totalStakers = 0;
    }    

    function transferToken(address to,uint256 amount) external onlyOwner{
        require(newToken.transfer(to, amount), "Token transfer failed!");  
    }

    function getAmountStaked(address _user) public view returns(uint256) {
        return stakeInfos[_user].amount;
    }

    function claimReward(address _to) external returns (bool){
        require(addressStaked[_to] == true, "You are not participated");
        require(stakeInfos[_to].endTS < block.timestamp, "Stake Time is not over yet");
        require(stakeInfos[_to].claimed == 0, "Already claimed");
        
        stakeInfos[_to].finalPrice = getLatestPrice();
        uint256 stakeAmount = stakeInfos[_to].amount;
        
        uint256 totalTokens = stakeAmount + tokensToPay(_to);
        // uint256 totalTokens = stakeAmount;
        // uint256 totalTokens = tokensToPay(_to);
        
        stakeInfos[_to].claimed = totalTokens;
        newToken.transfer(_to, totalTokens);
        // newToken.transferFrom(newToken.owner(),_to, totalTokens);
        // newToken.transferFrom(_msgSender(), _to, totalTokens);
        stakeInfos[_to].amount = 0;

        emit Claimed(_to, totalTokens);

        return true;
    }

    function getTokenExpiry() external view returns (uint256) {
        require(addressStaked[_msgSender()] == true, "You are not participated");
        return stakeInfos[_msgSender()].endTS;
    }

    function testingTransfer(uint256 microTokensToStake) public {
        newToken.transfer(address(this), microTokensToStake);
    }

    // stakeAmount must be scale by a factor of 10^18, that is we are working with microTokensToStake
    function stakeToken(uint256 microTokensToStake, uint256 _stakingDays) external payable whenNotPaused {
        require(microTokensToStake >0, "Stake amount should be correct");
        require(block.timestamp < planExpired , "Plan Expired");
        require(addressStaked[_msgSender()] == false, "You already participated");
        require(newToken.balanceOf(_msgSender()) >= microTokensToStake, "Insufficient Balance");
        
        newToken.transferFrom(_msgSender(), address(this), microTokensToStake);
        // newToken.transferFrom(_msgSender(), owner(), microTokensToStake);
        // newToken.transfer(address(this), microTokensToStake);
        totalStakers++;
        addressStaked[_msgSender()] = true;

        stakeInfos[_msgSender()] = StakeInfo({                
            startTS: block.timestamp,
            endTS: block.timestamp + _stakingDays,
            amount: microTokensToStake,
            stakingDays: _stakingDays,
            claimed: 0,
            interest: interestRate,
            initialPrice: getLatestPrice(),
            finalPrice: getLatestPrice()
        });
        
        emit Staked(_msgSender(), microTokensToStake);
    }    


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setInterestRate(uint16 _interestRate) public onlyOwner{
        interestRate = _interestRate;
    }

    function getLatestPrice() public view returns(uint256){
        (,int latestPrice,,,) = priceFeed.latestRoundData();
        return uint256(latestPrice);
    }

    function calculationOfTheAmountOfInterest(address _user) public view returns(uint256){
        uint256 _stakeAmount = stakeInfos[_user].amount;
        uint256 _interestRate = stakeInfos[_user].interest;
        uint256 _stakingDays = stakeInfos[_user].stakingDays;
        // return _stakeAmount * _interestRate/10000 * stakingDays/365;
        return _stakeAmount * _interestRate * _stakingDays / (10000*365);
    }

    // IF we trade BTCUSD, we will need to read prices from chainlink oracles

    function tokenCalculationToCoverDepreciation(address _user) public view returns(uint256){
        uint256 _stakeAmount = stakeInfos[_user].amount;
        uint256 _initialPrice = stakeInfos[_user].initialPrice;
        uint256 _finalPrice = stakeInfos[_user].finalPrice;
        return (_stakeAmount*(_initialPrice - _finalPrice))/ _finalPrice;
    }

    function tokensToPay(address _user) public view returns(uint256){
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
        return max;
    }
}

// https://betterprogramming.pub/how-to-write-a-smart-contract-for-stake-the-token-a46fdb9221b6

