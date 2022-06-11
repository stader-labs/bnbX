import { HardhatRuntimeEnvironment } from "hardhat/types";
import { HardhatUserConfig, task } from "hardhat/config";
import { deployDirect, deployProxy } from "./scripts/tasks";

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
} from "./environment";

task("deployBnbXProxy", "Deploy BnbX Proxy only")
  .addPositionalParam("manager")
  .setAction(async ({ manager }, hre: HardhatRuntimeEnvironment) => {
    await deployProxy(hre, "BnbX", manager);
  });

task("deployBnbXImpl", "Deploy BnbX Implementation only").setAction(
  async (args, hre: HardhatRuntimeEnvironment) => {
    await deployDirect(hre, "BnbX");
  }
);

task("deployStakeManagerProxy", "Deploy StakeManager Proxy only")
  .addPositionalParam("bnbX")
  .addPositionalParam("manager")
  .addPositionalParam("tokenHub")
  .addPositionalParam("bcDepositWallet")
  .setAction(
    async (
      { bnbX, manager, tokenHub, bcDepositWallet },
      hre: HardhatRuntimeEnvironment
    ) => {
      await deployProxy(
        hre,
        "StakeManager",
        bnbX,
        manager,
        tokenHub,
        bcDepositWallet
      );
    }
  );

task(
  "deployStakeManagerImpl",
  "Deploy StakeManager Implementation only"
).setAction(async (args, hre: HardhatRuntimeEnvironment) => {
  await deployDirect(hre, "StakeManager");
});

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
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    testnet: {
      url: SMART_CHAIN_RPC,
      chainId: 97,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
  },
  gasReporter: {
    currency: "USD",
    gasPrice: Number(GAS_PRICE),
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
};

export default config;
