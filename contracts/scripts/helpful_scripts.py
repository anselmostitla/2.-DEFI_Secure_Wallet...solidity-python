from brownie import accounts, network, config, MockV3Aggregator, MockV3AggregatorForLink, LinkToken, Contract
import time

LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local"]

DECIMALS = 8
# STARTING_PRICE = 200000000000
STARTING_PRICE = 161600000000


def get_account(index):
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return accounts[index]
    else:
        return accounts.add(config["wallets"]["from_key"][index])

# def deploy_mocks(_STARTING_PRICE):
#     print(f"The active network is {network.show_active()}")
#     print(f"Deploying Mocks... ")
#     account = get_account(0)
#     tx = MockV3Aggregator.deploy(DECIMALS, _STARTING_PRICE, {"from":account})
#     time.sleep(2)
#     print("Mocks deployed!")
    

# def deploy_mock_of_link_token():
#     print(f"Deploying Mock of LINK TOKEN... ")
#     Mock_of_link_token.deploy({"from":get_account(0)})
    
    
contract_to_mock = {
    "eth_usd_price_feed": MockV3Aggregator,
    "link_usd_price_feed":MockV3AggregatorForLink,
    "link_token": LinkToken,
}
    
def get_contract(contract_name):
    contract_type = contract_to_mock[contract_name]
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        if len(contract_type)<=0:
            deploy_mocks()
        contract = contract_type[-1]
    else:
        contract_address = config["networks"][network.show_active()][contract_name]
        contract = Contract.from_abi(contract_type._name, contract_address, contract_type.abi)
    return contract


def deploy_mocks():
    account = get_account(0)
    MockV3Aggregator.deploy(DECIMALS, 1300*10**8, {"from": account})
    MockV3AggregatorForLink.deploy(DECIMALS, 8*10**8, {"from": account})
    LinkToken.deploy({"from": account})
    print("Mocks deployed!")
        
    