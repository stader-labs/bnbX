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
  CHAIN_ID,
  GAS_PRICE,
} from "./environment";

task("deployBnbXProxy", "Deploy BnbX Proxy only")
  .addPositionalParam("manager")
  .setAction(async ({ admin }, hre: HardhatRuntimeEnvironment) => {
    await deployProxy(hre, "BnbX", admin);
  });

task("deployBnbXImpl", "Deploy BnbX Implementation only").setAction(
  async (args, hre: HardhatRuntimeEnvironment) => {
    await deployDirect(hre, "BnbX");
  }
);

task("deployStakeManagerProxy", "Deploy StakeManager Proxy only")
  .addPositionalParam("bnbX")
  .addPositionalParam("admin")
  .addPositionalParam("manager")
  .addPositionalParam("tokenHub")
  .addPositionalParam("bcDepositWallet")
  .addPositionalParam("bot")
  .addPositionalParam("feeBps")
  .setAction(
    async (
      { bnbX, admin, manager, tokenHub, bcDepositWallet, bot, feeBps },
      hre: HardhatRuntimeEnvironment
    ) => {
      await deployProxy(
        hre,
        "StakeManager",
        bnbX,
        admin,
        manager,
        tokenHub,
        bcDepositWallet,
        bot,
        feeBps
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
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    mainnet: {
      url: SMART_CHAIN_RPC,
      chainId: Number(CHAIN_ID),
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
    testnet: {
      url: SMART_CHAIN_RPC,
      chainId: Number(CHAIN_ID),
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
