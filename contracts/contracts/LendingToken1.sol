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

contract LendingToken1 is Pausable, Ownable, ReentrancyGuard {
    IERC20 myToken;
    Token newToken;
    
    // 180 Days (180 * 24 * 60 * 60)
    uint256 _planExpired = 15552000;

    uint256 public planExpired;
    uint8 public totalStakers;

    struct StakeInfo {        
        uint256 startTS;
        uint256 endTS;        
        uint256 amount; 
        uint256 stakingDays;
        uint256 claimed;   
    }
    
    event Staked(address indexed from, uint256 amount);
    event Claimed(address indexed from, uint256 amount);
    
    mapping(address => StakeInfo) public stakeInfos;
    mapping(address => bool) public addressStaked;

    
    constructor() {            
        planExpired = block.timestamp + _planExpired;
        totalStakers = 0;
    }    


    function getTime() public view returns(uint256){
        return block.timestamp;
    }


    function claimReward(address _to) external returns (bool){
        require(addressStaked[_to] == true, "You are not participated");
        require(stakeInfos[_to].endTS < block.timestamp, "Stake Time is not over yet");
        require(stakeInfos[_to].claimed == 0, "Already claimed");
        
        // uint256 stakeAmount = stakeInfos[_to].amount;
        
        // uint256 totalTokens = stakeAmount; 
        // uint256 totalTokens = stakeAmount;
        // uint256 totalTokens = tokensToPay(_to);
        
        // stakeInfos[_to].claimed = totalTokens;

        // stakeInfos[_to].amount = 0;

        // emit Claimed(_to, totalTokens);

        return true;
    }

    function getTokenExpiry() external view returns (uint256) {
        require(addressStaked[_msgSender()] == true, "You are not participated");
        return stakeInfos[_msgSender()].endTS;
    }


    // stakeAmount must be scale by a factor of 10^18, that is we are working with microTokensToStake
    function stakeToken(uint256 microTokensToStake, uint256 _stakingDays) external payable whenNotPaused {
        require(microTokensToStake >0, "Stake amount should be correct");
        require(block.timestamp < planExpired , "Plan Expired");
        require(addressStaked[_msgSender()] == false, "You already participated");
        // require(newToken.balanceOf(_msgSender()) >= microTokensToStake, "Insufficient Balance");
        
        // newToken.transferFrom(_msgSender(), address(this), microTokensToStake);
        totalStakers++;
        addressStaked[_msgSender()] = true;

        stakeInfos[_msgSender()] = StakeInfo({                
            startTS: block.timestamp,
            endTS: block.timestamp + _stakingDays,
            amount: microTokensToStake,
            stakingDays: _stakingDays,
            claimed: 0
        });
        
        emit Staked(_msgSender(), microTokensToStake);
    }    


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }



}

// https://betterprogramming.pub/how-to-write-a-smart-contract-for-stake-the-token-a46fdb9221b6

