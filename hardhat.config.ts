import { HardhatUserConfig, task } from "hardhat/config";

import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@openzeppelin/hardhat-upgrades";
import "@openzeppelin/hardhat-defender";
import "hardhat-gas-reporter";
import "solidity-coverage";

import {
  DEPLOYER_PRIVATE_KEY,
  ETHERSCAN_API_KEY,
  SMART_CHAIN_RPC,
  GAS_PRICE,
  DEFENDER_TEAM_API_KEY,
  DEFENDER_TEAM_API_SECRET_KEY,
} from "./environment";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.4",
      },
    ],
  },
  networks: {
    mainnet: {
      url: SMART_CHAIN_RPC,
      accounts: [DEPLOYER_PRIVATE_KEY],
      gasPrice: Number(GAS_PRICE),
    },
    testnet: {
      url: SMART_CHAIN_RPC,
      accounts: [DEPLOYER_PRIVATE_KEY],
      gasPrice: Number(GAS_PRICE),
    },
  },
  gasReporter: {
    currency: "USD",
    gasPrice: Number(GAS_PRICE),
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  defender: {
    apiKey: DEFENDER_TEAM_API_KEY,
    apiSecret: DEFENDER_TEAM_API_SECRET_KEY,
  },
};

export default config;
