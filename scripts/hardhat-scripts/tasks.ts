import { HardhatRuntimeEnvironment } from "hardhat/types";

export async function deployDirect(
  hre: HardhatRuntimeEnvironment,
  contractName: string,
  ...args: any
) {
  const contractFactory = await hre.ethers.getContractFactory(contractName);

  console.log(`Deploying ${contractName}: ${args}, ${args.length}`);
  let contract = args.length
    ? await contractFactory.deploy(...args)
    : await contractFactory.deploy();

  contract = await contract.waitForDeployment();

  console.log(`${contractName} deployed to:`, await contract.getAddress());
}

export async function deployProxy(
  hre: HardhatRuntimeEnvironment,
  contractName: string,
  ...args: any
) {
  const contractFactory = await hre.ethers.getContractFactory(contractName);

  console.log(`Deploying proxy ${contractName}: ${args}, ${args.length}`);
  let contract = args.length
    ? await hre.upgrades.deployProxy(contractFactory, args)
    : await hre.upgrades.deployProxy(contractFactory);

  contract = await contract.waitForDeployment();

  const contractImplAddress =
    await hre.upgrades.erc1967.getImplementationAddress(
      await contract.getAddress()
    );

  console.log(
    `Proxy ${contractName} deployed to:`,
    await contract.getAddress()
  );
  console.log(`Impl ${contractName} deployed to:`, contractImplAddress);
}

export async function upgradeProxy(
  hre: HardhatRuntimeEnvironment,
  contractName: string,
  proxyAddress: string
) {
  const contractFactory = await hre.ethers.getContractFactory(contractName);

  console.log(`Upgrading ${contractName} with proxy at: ${proxyAddress}`);

  let contract = await hre.upgrades.upgradeProxy(proxyAddress, contractFactory);
  contract = await contract.waitForDeployment();

  const contractImplAddress =
    await hre.upgrades.erc1967.getImplementationAddress(proxyAddress);

  console.log(
    `Proxy ${contractName} deployed to:`,
    await contract.getAddress()
  );
  console.log(`Impl ${contractName} deployed to:`, contractImplAddress);
}
