import { HardhatRuntimeEnvironment } from "hardhat/types";

export async function deployDirect(
  hre: HardhatRuntimeEnvironment,
  contractName: string,
  ...args: any
) {
  const Contract = await hre.ethers.getContractFactory(contractName);

  console.log(`Deploying ${contractName}: ${args}, ${args.length}`);
  const contract = args.length
    ? await Contract.deploy(...args)
    : await Contract.deploy();

  await contract.deployed();

  console.log(`${contractName} deployed to:`, contract.address);
}

export async function deployProxy(
  hre: HardhatRuntimeEnvironment,
  contractName: string,
  ...args: any
) {
  const Contract = await hre.ethers.getContractFactory(contractName);

  console.log(`Deploying proxy ${contractName}: ${args}, ${args.length}`);
  const contract = args.length
    ? await hre.upgrades.deployProxy(Contract, args)
    : await hre.upgrades.deployProxy(Contract);

  await contract.deployed();

  console.log(`Proxy ${contractName} deployed to:`, contract.address);
}
