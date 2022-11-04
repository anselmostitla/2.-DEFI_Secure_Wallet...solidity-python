from brownie import accounts, network, config, MockV3Aggregator
import time

LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local"]

DECIMALS = 8
# STARTING_PRICE = 200000000000
STARTING_PRICE = 161600000000

# def get_account(id=None, index = None):
#     if id:
#         return accounts.load(id)
#     if index:
#         return accounts[index]
#     if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
#         return accounts[0]
#     return accounts.add(config["wallets"]["from_key1"])


def get_account(index):
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return accounts[index]
    else:
        return accounts.add(config["wallets"]["from_key"][index])

def deploy_mocks():
    print(f"The active network is {network.show_active()}")
    print(f"Deploying Mocks... ")
    account = get_account(0)
    tx = MockV3Aggregator.deploy(DECIMALS, STARTING_PRICE, {"from":account})
    time.sleep(2)
    print("Mocks deployed!")
        
    