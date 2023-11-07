import * as tenderly from "@tenderly/hardhat-tenderly";
import "solidity-docgen";
import '@nomicfoundation/hardhat-verify';
import '@nomicfoundation/hardhat-ethers';

import "@dirtycajunrice/hardhat-tasks/internal/type-extensions"
import "@dirtycajunrice/hardhat-tasks";
import "dotenv/config";
import "./src/tasks";
import '@openzeppelin/hardhat-upgrades';

import { NetworksUserConfig } from "hardhat/types";

tenderly.setup({ automaticVerifications: false });

const networkData = [
  {
    name: "avalanche",
    chainId: 43_114,
    urls: {
      rpc: `https://api.avax.network/ext/bc/C/rpc`,
      api: "https://api.snowtrace.io/api",
      browser: "https://snowtrace.io",
    },
  },
  {
    name: "dfk",
    chainId: 53_935,
    urls: {
      rpc: `https://subnets.avax.network/defi-kingdoms/dfk-chain/rpc`,
      api: "https://api.routescan.io/v2/network/mainnet/evm/53935/etherscan",
      browser: "https://53935.routescan.io",
    },
  },
  {
    name: "dfk-testnet",
    chainId: 335,
    urls: {
      rpc: `https://subnets.avax.network/defi-kingdoms/dfk-chain-testnet/rpc`,
      api: "https://api.routescan.io/v2/network/testnet/evm/335/etherscan",
      browser: "https://subnets-test.avax.network/defi-kingdoms/",
    },
  },
  {
    name: "klaytn",
    chainId: 8_217,
    urls: {
      rpc: `https://public-node-api.klaytnapi.com/v1/cypress`,
      api: "https://scope.klaytn.com/api",
      browser: "https://scope.klaytn.com/",
    },
  }
];

module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [ "8.20" ].map(v => (
      {
        version: `0.${v}`,
        settings: {
          ...(
            v === "8.20" ? { evmVersion: "london" } : {}
          ), optimizer: { enabled: true, runs: 200 }
        },
      }
    )),
  },
  networks: networkData.reduce((o, network) => {
    o[network.name] = {
      url: network.urls.rpc,
      chainId: network.chainId,
      accounts: [ process.env.PRIVATE_KEY! ]
    }
    return o;
  }, {} as NetworksUserConfig),
  etherscan: {
    apiKey: networkData.reduce((o, network) => {
      o[network.name] = process.env[`${network.name.toUpperCase().replace("-", "_")}_API_KEY`] || "not-needed";
      return o;
    }, {} as Record<string, string>),
    customChains: networkData.map(network => (
      {
        network: network.name,
        chainId: network.chainId,
        urls: { apiURL: network.urls.api, browserURL: network.urls.browser },
      }
    ))
  },
  paths: {
    sources: "./src",
    tests: "./src/test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  tenderly: {
    project: 'DarkMarket',
    username: 'drkmkt',
  },
  solidityDocgen: {
    sourcesDir: "./src/contracts",
  }
};
