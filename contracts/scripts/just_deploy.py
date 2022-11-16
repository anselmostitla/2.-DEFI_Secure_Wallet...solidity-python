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
    min_staking_days = 90*24*60*60 # 90*24*60*60
    StakeToken.deploy(
        CreateToken[-1], interest_rate, price_feed_address, min_staking_days,{"from": account0}
    )
    
    
    
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
    
    
     
def main():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        # deploy_CreateToken()
        # deploy_BuyToken()
        # deploy_StakeToken()
        deploy_LendingToken()