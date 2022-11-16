from brownie import config, network, CreateToken, BuyToken, StakeToken, LendingToken
from brownie import MockV3Aggregator, MockV3AggregatorForLink, LinkToken

from scripts.helpful_scripts import LOCAL_BLOCKCHAIN_ENVIRONMENTS, get_account
from scripts.helpful_scripts import deploy_mocks, get_contract

import math, time

STARTING_PRICE_ETH = 130000000000
STARTING_PRICE_LINK = 800000000
_link_token_address = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"


def deploy_CreateToken():
    account0 = get_account(0)
    CreateToken.deploy({"from": account0})


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
    SPENDER = BuyToken[-1]  # or intermediary
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        micro_tokens_to_buy = get_micro_tokens_to_buy(_wei_to_spend=10**10)   # <--- <--- <--- <---
    else:        
        micro_tokens_to_buy = get_micro_tokens_to_buy(_wei_to_spend=1) 
    
    AMOUNT = micro_tokens_to_buy
    create_token.increaseAllowance(SPENDER, AMOUNT, {"from": FOUNDER})

    # SECOND PART:
    # A call to the buyToken function of the smart contract is performed with
    # the user address
    value = math.ceil(price_in_wei_of_tokens(AMOUNT))
    USER_1 = get_account(1)
    tx = buy_token.buyToken(AMOUNT, {"from": USER_1, "value": value})
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
    micro_tokens_to_buy = get_micro_tokens_to_buy(_wei_to_spend=1)
    AMOUNT = micro_tokens_to_buy
    create_token.increaseAllowance(SPENDER, AMOUNT, {"from": FOUNDER})

    value = math.ceil(price_in_wei_of_tokens(AMOUNT))

    USER_2 = get_account(2)
    tx = buy_token.buyToken(AMOUNT, {"from": USER_2, "value": value})
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
        price_feed_address = config["networks"][network.show_active()][
            "eth_usd_price_feed"
        ]

    interest_rate = 9000  # means 90.00% <--- <--- <--- <--- <---
    # for testing, instead of true 10 days (= 10 * 24 * 60 * 60), we will work 
    # with 10 seconds as if they were days.
    min_staking_days = 10*1*1*1 # 90*24*60*60
    StakeToken.deploy(
        CreateToken[-1], interest_rate, price_feed_address, min_staking_days,{"from": account0}
    )


def StakeToken_interaction_I():
    create_token = CreateToken[-1]
    stake_token = StakeToken[-1]
    # First the founder transfer certain amount of new tokens to the Contract to pay
    # for future interest generated and capital payments claim by stakers.
    create_token.transfer(stake_token, 10**24)


    # for testing, instead of true 10 days (= 10 * 24 * 60 * 60), we will work 
    # with 10 seconds as if they were days.
    days = 10 * 1 * 1 * 1
    stake_amount = create_token.balanceOf(get_account(1))

    # As a user, I have certain amount of microTokens, say 161600. First, I authorize
    # the spender, that is the "stake_token contract", an amount of microTokens.
    tx = create_token.increaseAllowance(
        stake_token.address, stake_amount, {"from": get_account(1)}
    )
    tx.wait(1)
    # Then I transfer an amount of microTokens to the StakeToken contract, not to the owner
    tx = stake_token.stakeToken(stake_amount, {"from": get_account(1)})
    tx.wait(1)

    print(f"StakeToken_interaction_I")
    tx1 = create_token.balanceOf(get_account(0))
    print(f"BALANCE OWNER: {tx1}")
    tx2 = create_token.balanceOf(get_account(1))
    print(f"BALANCE user_1: {tx2}")
    tx3 = create_token.balanceOf(get_account(2))
    print(f"BALANCE user_2: {tx3}")
    tx4 = create_token.balanceOf(stake_token)
    print(f"BALANCE stake_token: {tx4}")
    tx5 = create_token.balanceOf(create_token)
    print(f"BALANCE create_token: {tx5}")

    print(f"The sum: {tx1 + tx2 + tx3 + tx4 + tx5}")
    time.sleep(days+1)

    # # print(f"LatestPrice: {stake_token.getLatestPrice()}")
    # # tx = stake_token.calculationOfTheAmountOfInterest(get_account(1),{"from": get_account(1)})
    # # time.sleep(1)
    # # print(f"calculationOfTheAmountOfInterest: {tx}")
    # # tx = stake_token.tokenCalculationToCoverDepreciation(get_account(1),{"from": get_account(1)})
    # # time.sleep(1)
    # # print(f"tokenCalculationToCoverDepreciation: {tx}")
    # # tx = stake_token.tokensToPay(get_account(1),{"from":get_account(1)})
    # # time.sleep(1)
    # # print(f"tokensToPay: {tx}")

    # # Now, as a user, I want to claim my tokens from the owner, so I have to ask the owner to authorize,
    # # the spender certain amount of tokens to be transferred to me,

    # # tx = create_token.increaseAllowance(stake_token.address, 1000,{"from":get_account(0)})
    # # tx = create_token.increaseAllowance(get_account(1), stake_amount,{"from":get_account(0)})
    # # tx.wait(1)
    # stake_token.getCurrentTime()
    # print(f"currentMoment1: {stake_token.getCurrentMoment()}")


def StakeToken_interaction_II():
    # In this part I will test the function increaseStaking
    create_token = CreateToken[-1]
    stake_token = StakeToken[-1]
    buy_token = BuyToken[-1]
    
    # First the user has to buy more newTokens to increase staking
    FOUNDER = get_account(0)
    SPENDER = BuyToken[-1]  # or intermediary
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        micro_tokens_to_buy = get_micro_tokens_to_buy(_wei_to_spend=10**10)   # <--- <--- <--- <---
    else:
        micro_tokens_to_buy = get_micro_tokens_to_buy(_wei_to_spend=1)   # <--- <--- <--- <---    
    AMOUNT = micro_tokens_to_buy
    create_token.increaseAllowance(SPENDER, AMOUNT, {"from": FOUNDER})
    # A call to the buyToken function of the smart contract is performed with
    # the user address
    value = math.ceil(price_in_wei_of_tokens(AMOUNT))
    USER_1 = get_account(1)
    tx = buy_token.buyToken(AMOUNT, {"from": USER_1, "value": value})
    tx.wait(1)

    balance_founder = create_token.balanceOf(FOUNDER)
    balance_user_1 = create_token.balanceOf(USER_1)
    print(f"balanceOf(FOUNDER): {balance_founder}")
    print(f"USER_1 new tokens: {balance_user_1}")
    print(f"Sum: {balance_founder + balance_user_1}")
    
    # As a user, I have certain amount of microTokens, say 161600. First, I authorize
    # the spender, that is the "stake_token contract", an amount of microTokens.
    
    tx = create_token.increaseAllowance(
        stake_token.address, AMOUNT, {"from": get_account(1)}
    )
    tx.wait(1)
    # Then I transfer an amount of microTokens to the StakeToken contract, not to the owner
    tx = stake_token.increaseStaking(AMOUNT, {"from": get_account(1)})
    tx.wait(1)
    
    tx = stake_token.stakeInfos(get_account(1))
    print(f"Amount Satked User_1: {tx}")
    
    report_balances()


def report_balances():
    create_token = CreateToken[-1]
    stake_token = StakeToken[-1]
    buy_token = BuyToken[-1]

    tx1 = create_token.balanceOf(get_account(0))
    print(f"BALANCE OWNER: {tx1}")
    tx2 = create_token.balanceOf(get_account(1))
    print(f"BALANCE user_1: {tx2}")
    tx3 = create_token.balanceOf(get_account(2))
    print(f"BALANCE user_2: {tx3}")
    tx4 = create_token.balanceOf(stake_token)
    print(f"BALANCE stake_token: {tx4}")
    tx5 = create_token.balanceOf(create_token)
    print(f"BALANCE create_token: {tx5}")

    print(f"The sum: {tx1 + tx2 + tx3 + tx4 + tx5}")

    
    
    
    
    


def StakeToken_interaction_III():
    print(f"StakeToken_interaction_III...")
    days = 10 * 1 * 1 * 1
    time.sleep(days + 1)
    # This part is for testing the unstaking part
    create_token = CreateToken[-1]
    stake_token = StakeToken[-1]
    
    # stake_token.getCurrentTime()
    # print(f"currentMoment2: {stake_token.getCurrentMoment()}")

    # Now, as a user, I want to claim my tokens from the StakeToken contract,

    tx = stake_token.claimReward(get_account(1), {"from": get_account(0)})
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
    
    


def deploy_LendingToken():
    account0 = get_account(0)
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        price_feed_address = config["networks"][network.show_active()][
            "eth_usd_price_feed"
        ]
        link_price_feed_address = config["networks"][network.show_active()][
            "link_usd_price_feed"
        ]
        link_token_address = _link_token_address
    else:
        deploy_mocks()
        price_feed_address = MockV3Aggregator[-1].address
        link_price_feed_address = MockV3AggregatorForLink[-1].address
        link_token_address = LinkToken[-1].address

    interesRateForDebt = 125  # (means 1.25%)
    maxPercentForLending = 7000  # means 70.00%

    LendingToken.deploy(
        StakeToken[-1],
        link_token_address,
        price_feed_address,
        link_price_feed_address,
        interesRateForDebt,
        maxPercentForLending,
        {"from": account0},
    )


def LendingToken_interaction_I():
    print(f"LendingToken_interaction_I")
    # In this part we interact with some functions of the smart contract
    # in order to test them.
    
    INTEREST_RATE_FOR_BORROWED_ASSET = 9900 # means 99.00%
    MAX_PERCENT_FOR_BORROWED_ASSET = 7500 # means 75.00%
    
    lending_token = LendingToken[-1]

    lending_token.setMaxPercentForLending(MAX_PERCENT_FOR_BORROWED_ASSET, {"from": get_account(0)})
    print(lending_token.maxPercentForLending())
    
    lending_token.setInteresRateForDebt(INTEREST_RATE_FOR_BORROWED_ASSET, {"from": get_account(0)})
    print(lending_token.interesRateForDebt())

    eth = True
    print(lending_token.getTokenLatestPrice(eth))
    link = False
    print(lending_token.getTokenLatestPrice(link))

    microTokensToUsd = lending_token.priceInUsd(10000)
    print(f"microTokensToUsd: {microTokensToUsd}")

    microTokensToLink = lending_token.priceInLink(microTokensToUsd)
    print(f"microTokensToLink: {microTokensToLink}")

    microTokensToLink = lending_token.convertMicroTokensToLink(10**18)
    print(f"microTokensToLink: {microTokensToLink}")
    
    
def LendingToken_interaction_II():
    LENDING_PERCENT = 7000 # means 70.00%
    
    lending_token = LendingToken[-1]

    tokens_staked = lending_token.amountOfMicroTokensStaked({"from": get_account(1)})
    print(f"Micro Tokens Staked user_1: {tokens_staked}")

    microTokensToLink = lending_token.convertMicroTokensToLink(tokens_staked)
    print(f"microTokensToLink: {microTokensToLink}")

    amount_of_lending = lending_token.getAmountOfLending(
        LENDING_PERCENT, {"from": get_account(1)}
    )
    print(f"User borrowing amount, {LENDING_PERCENT/100}%: {amount_of_lending}")
    
    # Here... the user will borrow some links, say 50%, 60%, 70% etc.
    # But first the owner has to authorize some links...

    link_token = get_contract("link_token")
    tx = link_token.increaseAllowance(
        lending_token.address, amount_of_lending, {"from": get_account(0)}
    )
    tx.wait(1)

    tx = lending_token.lendingProcesser(LENDING_PERCENT, {"from": get_account(1)})
    tx.wait(1)

    tx1 = link_token.balanceOf(get_account(0))
    print(f"Links of owner: {tx1}")
    tx2 = link_token.balanceOf(get_account(1))
    print(f"Links of user_1: {tx2}")
    tx3 = link_token.balanceOf(get_account(2))
    print(f"Links of user_2: {tx3}")

    print(f"The sum: {tx1 + tx2 + tx3}")


def LendingToken_interaction_III():
    create_token = CreateToken[-1]
    lending_token = LendingToken[-1]
    stake_token = StakeToken[-1]

    # 10, 20, 60 etc, days later

    days = 19 * 1 * 1 * 1  # every 14 seconds a new block is generated
    time.sleep(days + 1)

    # tx = stake_token.tokensToPay(get_account(1), {"from": get_account(1)})
    # time.sleep(1)
    # print(f"Rewards for having staking microtokens: {tx}")

    tx20 = lending_token.totalDebtCalculationOfLendingCurrency({"from": get_account(1)})
    tx20.wait(1)
    print(f"Links in debt: {lending_token.totalDebtAmount()}")
    
    link_token = get_contract("link_token")
    total_debt = link_token.balanceOf(get_account(1)) + lending_token.totalDebtAmount()
    tx21 = link_token.increaseAllowance(
        lending_token.address, total_debt/2, {"from": get_account(1)}
    )
    tx21.wait(1)
    
    print(f"Links in total debt: {total_debt}")
    
    # Testing repaying only half of total debt because I do not have enought links 
    # to pay the lending plus interest.
    tx = lending_token.repay(total_debt/2, {"from": get_account(1)})
    tx.wait(1)


def main():

    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        deploy_CreateToken()
        deploy_BuyToken()
        deploy_StakeToken()
        deploy_LendingToken()

    buy_token_interaction()

    StakeToken_interaction_I()
    StakeToken_interaction_II()

    # LendingToken_interaction_I()
    # LendingToken_interaction_II()

    # StakeToken_interaction_III()

    # LendingToken_interaction_III()

    
