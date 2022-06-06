import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, upgrades } from "hardhat";
import { BnbX, StakeManager } from "../typechain";

describe("Stake Manager Contract", () => {
  let deployer: SignerWithAddress;
  let manager: SignerWithAddress;
  let users: SignerWithAddress[];
  let depositWallet: SignerWithAddress;

  let bnbX: BnbX;
  let stakeManager: StakeManager;

  beforeEach(async () => {
    [deployer, ...users] = await ethers.getSigners();
    manager = deployer;
    depositWallet = users[2];

    bnbX = (await upgrades.deployProxy(
      await ethers.getContractFactory("BnbX"),
      [manager.address]
    )) as BnbX;
    await bnbX.deployed();

    stakeManager = (await upgrades.deployProxy(
      await ethers.getContractFactory("StakeManager"),
      [bnbX.address, manager.address, depositWallet.address]
    )) as StakeManager;
    await stakeManager.deployed();

    await bnbX.setStakeManager(stakeManager.address);
  });

  it("Should convert Bnb to BnbX properly", async () => {
    const amount = BigNumber.from("700");
    const amountInBnbX = await stakeManager.convertBnbToBnbX(amount);
    expect(amountInBnbX).to.be.eq(amount);
  });

  it("Should Pool Bnb and get BnbX back", async () => {
    const amount = BigNumber.from("300");
    const zeroBalance = BigNumber.from("0");
    let depositWalletBalance = await depositWallet.getBalance();

    expect(await bnbX.balanceOf(deployer.address)).to.be.eq(zeroBalance);

    await stakeManager.deposit({ value: amount });

    // deployer bnbX balance should increase
    expect(await bnbX.balanceOf(deployer.address)).to.be.eq(amount);

    // depositWallet bnb balance should increase
    depositWalletBalance = depositWalletBalance.add(amount);
    expect(await depositWallet.getBalance()).to.be.eq(depositWalletBalance);

    // normal user pools bnb
    const user = users[0];
    expect(await bnbX.balanceOf(user.address)).to.be.eq(zeroBalance);

    stakeManager = stakeManager.connect(user);
    await stakeManager.deposit({ value: amount });

    // user bnbX balance should increase
    expect(await bnbX.balanceOf(deployer.address)).to.be.eq(amount);

    // depositWallet bnb balance should increase
    depositWalletBalance = depositWalletBalance.add(amount);
    expect(await depositWallet.getBalance()).to.be.eq(depositWalletBalance);
  });
});
