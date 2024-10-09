import { ethers, upgrades } from "hardhat";

async function main() {
  const stakeManagerContractFactory = await ethers.getContractFactory(
    "StakeManager"
  );
  const stakeManagerContract = await stakeManagerContractFactory.deploy();

  await stakeManagerContract.waitForDeployment();

  console.log(
    "StakeManager Contract impl deployed to:",
    await stakeManagerContract.getAddress()
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
