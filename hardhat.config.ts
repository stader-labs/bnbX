import { HardhatRuntimeEnvironment } from "hardhat/types";
import { HardhatUserConfig, task } from "hardhat/config";
import { deployDirect, deployProxy, upgradeProxy } from "./scripts/tasks";

import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@openzeppelin/hardhat-upgrades";
import "@openzeppelin/hardhat-defender";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-forta";

import {
  DEPLOYER_PRIVATE_KEY,
  ETHERSCAN_API_KEY,
  SMART_CHAIN_RPC,
  CHAIN_ID,
  GAS_PRICE,
} from "./environment";

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
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.24",
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
