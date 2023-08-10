# Dark Market Auctions


[Auction Example](https://avascan.info/blockchain/dfk/home)


# About

This project is a bid-to-earn auction used to sell ERC721 tokens and incentivize bidders.

- [Foundry DeFi Stablecoin](#foundry-defi-stablecoin)
- [About](#about)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
    - [Optional Gitpod](#optional-gitpod)
- [Updates](#updates)
- [Usage](#usage)
  - [Start a local node](#start-a-local-node)
  - [Deploy](#deploy)
  - [Deploy - Other Network](#deploy---other-network)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)
- [Deployment to a testnet or mainnet](#deployment-to-a-testnet-or-mainnet)
  - [Scripts](#scripts)
  - [Estimate gas](#estimate-gas)
- [Formatting](#formatting)
- [Thank you!](#thank-you)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/Elite-Oracle/drkmkt-sol.git
cd DarkMarketAuction
forge build
```

### Optional Gitpod

If you can't or don't want to run and install locally, you can work with this repo in Gitpod. If you do this, you can skip the `clone this repo` part.

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#github.com/Elite-Oracle/Drkmkt-sol)

# Updates
- The latest version of openzeppelin-contracts has changes in the ERC20Mock file. To follow along with the course, you need to install version 4.8.3 which can be done by ```forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit``` instead of ```forge install openzeppelin/openzeppelin-contracts --no-commit```

# Usage

## Start a local node

```
make anvil
```

## Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

```
make deploy
```

## Deploy - Other Network

[See below](#deployment-to-a-testnet-or-mainnet)

## Testing

We talk about 4 test tiers in the video. 

1. Unit
2. Integration
3. Forked
4. Staging

In this repo we cover #1 and Fuzzing. 

```
forge test
```

### Test Coverage

```
forge coverage
```

and for coverage based testing: 

```
forge coverage --report debug
```


# Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables. You can add them to a `.env` file, similar to what you see in `.env.example`.

- `PRIVATE_KEY`: The private key of your account (like from [metamask](https://metamask.io/)). **NOTE:** FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
  - You can [learn how to export it here](https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-Export-an-Account-Private-Key).
- `SEPOLIA_RPC_URL`: This is url of the sepolia testnet node you're working with. You can get setup with one for free from [Alchemy](https://alchemy.com/?a=673c802981)

Optionally, add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).

1. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH. You should see the ETH show up in your metamask.

2. Deploy

```
make deploy ARGS="--network sepolia"
```

## Scripts

Instead of scripts, we can directly use the `cast` command to interact with the contract. 

For example, on Sepolia:

1. Get some WETH 

```
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "deposit()" --value 0.1ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

2. Approve the WETH

```
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "approve(address,uint256)" 0x091EA0838eBD5b7ddA2F2A641B068d6D59639b98 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

3. Start Auction

```
Auctions
```


## Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see an output file called `.gas-snapshot`


# Formatting


To run code formatting:
```
forge fmt
```


# Thank you!

If you appreciated this, feel free to follow me or donate!

ETH/Arbitrum/Optimism/Polygon/etc Address: 0x0E127d74D1a5b5d8959173aD3448e6C72D4dD835

[![Kristian Peter Twitter](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/kristianpeter)
[![Kristian Peter YouTube](https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/kristianpeter)
[![Kristian Peter Linkedin](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/kristianpeter/)
