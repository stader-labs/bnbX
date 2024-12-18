import "dotenv/config";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { HardhatUserConfig, task } from "hardhat/config";
import {
  deployDirect,
  deployProxy,
  upgradeProxy,
} from "./script/hardhat-scripts/tasks";

import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@openzeppelin/hardhat-upgrades";

task("deployBnbXProxy", "Deploy BnbX Proxy only")
  .addPositionalParam("admin")
  .setAction(async ({ admin }, hre: HardhatRuntimeEnvironment) => {
    await deployProxy(hre, "BnbX", admin);
  });

task("upgradeBnbXProxy", "Upgrade BnbX Proxy")
  .addPositionalParam("proxyAddress")
  .setAction(async ({ proxyAddress }, hre: HardhatRuntimeEnvironment) => {
    await upgradeProxy(hre, "BnbX", proxyAddress);
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

task("upgradeStakeManagerProxy", "Upgrade StakeManager Proxy")
  .addPositionalParam("proxyAddress")
  .setAction(async ({ proxyAddress }, hre: HardhatRuntimeEnvironment) => {
    await upgradeProxy(hre, "StakeManager", proxyAddress);
  });

task(
  "deployStakeManagerImpl",
  "Deploy StakeManager Implementation only"
).setAction(async (args, hre: HardhatRuntimeEnvironment) => {
  await deployDirect(hre, "StakeManager");
});

task("deployReferralContract", "Deploy KOL Referral Contract")
  .addPositionalParam("admin")
  .addPositionalParam("trustedForwarder")
  .setAction(
    async ({ admin, trustedForwarder }, hre: HardhatRuntimeEnvironment) => {
      await deployProxy(hre, "KOLReferral", admin, trustedForwarder);
    }
  );

task("upgradeReferralContract", "Upgrade KOL Referral Contract")
  .addPositionalParam("proxyAddress")
  .setAction(async ({ proxyAddress }, hre: HardhatRuntimeEnvironment) => {
    await upgradeProxy(hre, "KOLReferral", proxyAddress);
  });

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.25",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: "cancun",
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
        },
      },
    ],
  },
  defaultNetwork: "hardhat",
  networks: {
    mainnet: {
      url: `${process.env.BSC_MAINNET_RPC_URL}`,
      chainId: 56,
      accounts: [process.env.DEV_PRIVATE_KEY ?? ""],
    },
    testnet: {
      url: `${process.env.BSC_TESTNET_RPC_URL}`,
      chainId: 97,
      accounts: [process.env.DEV_PRIVATE_KEY ?? ""],
    },
  },
  etherscan: {
    apiKey: process.env.BSC_SCAN_API_KEY,
  },
};

export default config;
