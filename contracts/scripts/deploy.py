from brownie import accounts, config, network, CreateToken, BuyToken, StakeToken, MockV3Aggregator
from scripts.helpful_scripts import (
    LOCAL_BLOCKCHAIN_ENVIRONMENTS,
    get_account,
    deploy_mocks,
)
import math, time


def deploy_CreateToken():
    account0 = get_account(0)
    account1 = get_account(1)
    CreateToken.deploy({"from": account0})
    print(f"deployer: {account0}")
    print(f"account1: {account1}")


def deploy_BuyToken():
    account0 = get_account(0)
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        price_feed_address = config["networks"][network.show_active()][
            "eth_usd_price_feed"
        ]
    else:
        deploy_mocks()
        price_feed_address = MockV3Aggregator[-1].address

    priceInUsd = 0.01
    scalePriceInUsd = priceInUsd * 10**18

    BuyToken.deploy(
        scalePriceInUsd,
        CreateToken[-1].address,
        price_feed_address,
        {"from": account0},
    )


def get_micro_tokens_to_buy(
    _tokens_to_buy=None, _micro_tokens_to_buy=None, _wei_to_spend=None
):
    buy_token = BuyToken[-1]
    if _tokens_to_buy:
        micro_tokens_to_buy = _tokens_to_buy * 10**18
    if _micro_tokens_to_buy:
        micro_tokens_to_buy = _micro_tokens_to_buy
    if _wei_to_spend:
        micro_tokens_to_buy = math.floor(
            _wei_to_spend * (1 * 10**18) / buy_token.priceInWei()
        )
        print(
            f"With {_wei_to_spend} wei(s) you can buy: {micro_tokens_to_buy} microTokens"
        )
    price_in_wei_of_tokens_to_buy = (
        buy_token.priceInWei() * micro_tokens_to_buy / (10**18)
    )
    msg = f"--> {micro_tokens_to_buy} microTokens will cost {price_in_wei_of_tokens_to_buy} wei(s),"
    msg += f"that is, rounding {math.ceil(price_in_wei_of_tokens_to_buy)} wei(s)"
    
    print(msg)
    return micro_tokens_to_buy


def price_in_wei_of_tokens(_micro_tokens_to_buy):
    price_wei = BuyToken[-1].priceInWei() * _micro_tokens_to_buy / (10**18)
    return price_wei
    
    

def buy_token_interaction():
    create_token = CreateToken[-1]
    buy_token = BuyToken[-1]

    micro_tokens_to_buy = get_micro_tokens_to_buy(_micro_tokens_to_buy=646400)
    micro_tokens_to_buy = get_micro_tokens_to_buy(_tokens_to_buy=1)
    micro_tokens_to_buy = get_micro_tokens_to_buy(_wei_to_spend=1)
    
    # HERE IS THE NEW PART
    
    # An user wants to buy certain amount of the new tokens. When the user clicks
    # the buy button in web page two things happen. 
    
    # FIRST PART:
    # The FOUNDER = account0, has to authorize the SPENDER = buy_token contract, an allowance.
    # An allowance to spend the founder's money. Think of it as the founder granting his
    # or her debit card, but the founder can limit the AMOUNT the smart contract can spend.
    print()
    print(f"FIRST USER  -- FIRST USER -- FIRST USER -- FIRST USER -- FIRST USER")
    print()
    
    FOUNDER = get_account(0)
    SPENDER = BuyToken[-1] # or intermediary
    micro_tokens_to_buy = get_micro_tokens_to_buy(_wei_to_spend=1)
    AMOUNT = micro_tokens_to_buy
    create_token.increaseAllowance(SPENDER, AMOUNT,{"from":FOUNDER})
    
    # SECOND PART:
    # A call to the buyToken function of the smart contract is performed with
    # the user address
    value = math.ceil(price_in_wei_of_tokens(AMOUNT))
    USER_1 = get_account(1)
    tx = buy_token.buyToken1(AMOUNT, {"from": USER_1, "value": value})
    tx.wait(1)
    
    balance_founder = create_token.balanceOf(FOUNDER)
    balance_user_1 = create_token.balanceOf(USER_1)
    print(f"balanceOf(FOUNDER): {balance_founder}")
    print(f"balanceOf(USER_1): {balance_user_1}")
    print(f"Sum: {balance_founder + balance_user_1}")
    
    # A second user wants to buy our new token.
    print()
    print(f"SECOND USER -- SECOND USER -- SECOND USER -- SECOND USER -- SECOND USER")
    print()
    micro_tokens_to_buy = get_micro_tokens_to_buy(_wei_to_spend=2)
    AMOUNT = micro_tokens_to_buy
    create_token.increaseAllowance(SPENDER, AMOUNT,{"from":FOUNDER})
    
    value = math.ceil(price_in_wei_of_tokens(AMOUNT))
    
    USER_2 = get_account(2)
    tx = buy_token.buyToken1(AMOUNT, {"from": USER_2, "value": value})
    tx.wait(1)
    
    balance_founder = create_token.balanceOf(FOUNDER)
    balance_user_1 = create_token.balanceOf(USER_1)
    balance_user_2 = create_token.balanceOf(USER_2)
    print(f"balanceOf(FOUNDER): {balance_founder}")
    print(f"balanceOf(USER_1): {balance_user_1}")
    print(f"balanceOf(USER_2): {balance_user_2}")
    
    print(f"Sum: {balance_founder + balance_user_1 + balance_user_2}")
    
    
    


def deploy_StakeToken():
    account0 = get_account(0)
    
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        deploy_mocks()
        price_feed_address = MockV3Aggregator[-1]
    else:
        price_feed_address = config["networks"][network.show_active()]["eth_usd_price_feed"]
        
    interest_rate = 1500 # means 15.00%
    StakeToken.deploy(CreateToken[-1], interest_rate, price_feed_address, {"from": account0})
    

def StakeToken_interaction():
    create_token = CreateToken[-1]
    stake_token = StakeToken[-1]
    # First the founder transfer certain amount of new tokens to the Contract to ppay
    # for future interest and capital payments claim by the stakers.
    create_token.transfer(stake_token, 10**24)
    
    # for testing, instead of 10 days (= 10 * 24 * 60 * 60), we will work with 10 seconds as if they were days.
    days = 10 * 1 * 1 * 1
    stake_amount = 1000
    
    # As a user, I have certain amount of microTokens, say 161600. First, I authorize
    # the spender, that is the stake_token contract, an amount of microTokens.
    tx=create_token.increaseAllowance(stake_token.address, stake_amount,{"from": get_account(1) })
    tx.wait(1)
    tx = stake_token.stakeToken(stake_amount, days, {"from": get_account(1) })
    tx.wait(1)
    
    tx1 = create_token.balanceOf(get_account(0))
    print(f"Balance of owner: {tx1}")
    tx2 = create_token.balanceOf(get_account(1))
    print(f"Balance of user_1: {tx2}")
    tx3 = create_token.balanceOf(get_account(2))
    print(f"Balance of user_2: {tx3}")
    tx4 = create_token.balanceOf(stake_token)
    print(f"Balance stake_token: {tx4}")
    tx5 = create_token.balanceOf(create_token)
    print(f"Balance create_token: {tx5}")
    
    print(f"The sum: {tx1 + tx2 + tx3 + tx4 + tx5}")
    time.sleep(days+1)
    
    
    # print(f"LatestPrice: {stake_token.getLatestPrice()}")
    # tx = stake_token.calculationOfTheAmountOfInterest(get_account(1),{"from": get_account(1)})
    # time.sleep(1)
    # print(f"calculationOfTheAmountOfInterest: {tx}")
    # tx = stake_token.tokenCalculationToCoverDepreciation(get_account(1),{"from": get_account(1)})
    # time.sleep(1)
    # print(f"tokenCalculationToCoverDepreciation: {tx}")
    # tx = stake_token.tokensToPay(get_account(1),{"from":get_account(1)})
    # time.sleep(1)
    # print(f"tokensToPay: {tx}")
    
    
    
    # Now, as a user, I want to claim my tokens from the owner, so I have to ask the owner to authorize, 
    # the spender certain amount of tokens to be transferred to me, 
    
    # tx = create_token.increaseAllowance(stake_token.address, 1000,{"from":get_account(0)})
    # tx = create_token.increaseAllowance(get_account(1), stake_amount,{"from":get_account(0)})
    # tx.wait(1)
    
    tx = stake_token.claimReward(get_account(1),{"from": get_account(0)})
    tx.wait(1)
    tx1 = create_token.balanceOf(get_account(0))
    print(f"Balance of owner: {tx1}")
    tx2 = create_token.balanceOf(get_account(1))
    print(f"Balance of user_1: {tx2}")
    tx3 = create_token.balanceOf(get_account(2))
    print(f"Balance of user_2: {tx3}")
    tx4 = create_token.balanceOf(stake_token)
    print(f"Balance stake_token: {tx4}")
    tx5 = create_token.balanceOf(create_token)
    print(f"Balance create_token: {tx5}")
    
    print(f"The sum: {tx1 + tx2 + tx3 + tx4 + tx5}")
    
    
def StakeToken_testingTransfer():
    create_token = CreateToken[-1]
    stake_token = StakeToken[-1]
    stake_amount = 500
    tx = create_token.balanceOf(get_account(1))
    print(f"Balance of user: {tx}")
    
    tx = create_token.transfer(stake_token.address,stake_amount,{"from": get_account(1)})
    tx.wait(1)
    
    tx = create_token.balanceOf(get_account(1))
    print(f"Balance of user: {tx}")    
    # stake_token.testingTransfer(stake_amount,{"from": get_account(1)})
    
    
    

    

    
    

def main():
    
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        deploy_CreateToken()
        deploy_BuyToken()
        deploy_StakeToken()


    buy_token_interaction()
    
    StakeToken_interaction()
    
    # StakeToken_testingTransfer()

