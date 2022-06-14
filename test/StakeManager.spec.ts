import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, upgrades } from "hardhat";
import { BnbX, TokenHubMock, StakeManager } from "../typechain";

describe("Stake Manager Contract", () => {
  let deployer: SignerWithAddress;
  let manager: SignerWithAddress;
  let users: SignerWithAddress[];
  let bcDepositWallet: SignerWithAddress;
  let bot: SignerWithAddress;
  let user: SignerWithAddress;

  let bnbX: BnbX;
  let stakeManager: StakeManager;
  let tokenHub: TokenHubMock;

  beforeEach(async () => {
    [deployer, ...users] = await ethers.getSigners();
    manager = deployer;
    user = users[0];
    bcDepositWallet = users[1];
    bot = users[2];

    bnbX = (await upgrades.deployProxy(
      await ethers.getContractFactory("BnbX"),
      [manager.address]
    )) as BnbX;
    await bnbX.deployed();

    tokenHub = (await (
      await ethers.getContractFactory("TokenHubMock")
    ).deploy()) as TokenHubMock;
    await tokenHub.deployed();

    stakeManager = (await upgrades.deployProxy(
      await ethers.getContractFactory("StakeManager"),
      [
        bnbX.address,
        manager.address,
        tokenHub.address,
        bcDepositWallet.address,
        bot.address,
      ]
    )) as StakeManager;
    await stakeManager.deployed();

    await bnbX.setStakeManager(stakeManager.address);
  });

  it("Should convert Bnb to BnbX properly", async () => {
    const amount = BigNumber.from("700");
    const amountInBnbX = await stakeManager.convertBnbToBnbX(amount);
    expect(amountInBnbX).to.be.eq(amount);
  });

  it("Should deposit Bnb and get BnbX back", async () => {
    const amount = BigNumber.from("300");
    const zeroBalance = BigNumber.from("0");

    // deployer
    expect(await bnbX.balanceOf(deployer.address)).to.be.eq(zeroBalance);
    await stakeManager.deposit({ value: amount });
    expect(await stakeManager.totalDeposited()).to.be.eq(amount);
    // deployer bnbX balance should increase
    expect(await bnbX.balanceOf(deployer.address)).to.be.eq(amount);

    // normal user deposits bnb
    expect(await bnbX.balanceOf(user.address)).to.be.eq(zeroBalance);
    stakeManager = stakeManager.connect(user);
    await stakeManager.deposit({ value: amount });
    expect(await stakeManager.totalUnstaked()).to.be.eq(amount.add(amount));
    // user bnbX balance should increase
    expect(await bnbX.balanceOf(deployer.address)).to.be.eq(amount);
  });

  describe("startDelegation", () => {
    let relayFee: BigNumber;

    beforeEach(async () => {
      stakeManager = stakeManager.connect(bot);
      relayFee = await tokenHub.relayFee();
    });

    it("Should fail if less or no relayFee is provided", async () => {
      // provided 0 relayFee
      await expect(stakeManager.startDelegation()).to.be.revertedWith(
        "Require More Relay Fee, Check getTokenHubRelayFee"
      );

      await expect(
        stakeManager.startDelegation({
          value: ethers.utils.parseEther("0.001"),
        })
      ).to.be.revertedWith("Require More Relay Fee, Check getTokenHubRelayFee");

      await expect(
        stakeManager.startDelegation({ value: relayFee })
      ).to.be.revertedWith("No more funds to stake");
    });

    it("Should fail when totalUnStaked funds is less than 1e10", async () => {
      const amount = BigNumber.from("300");
      const zeroBalance = BigNumber.from("0");

      expect(await stakeManager.totalUnstaked()).to.be.eq(zeroBalance);
      await expect(
        stakeManager.startDelegation({ value: relayFee })
      ).to.be.revertedWith("No more funds to stake");

      await stakeManager.deposit({ value: amount });
      expect(await stakeManager.totalUnstaked()).to.be.eq(amount);

      await expect(
        stakeManager.startDelegation({ value: relayFee })
      ).to.be.revertedWith("No more funds to stake");
    });

    it("Should transfer amount in multiples of 1e10", async () => {
      const smallAmount = BigNumber.from("300");
      let amount = ethers.utils.parseEther("0.1");
      amount = amount.add(smallAmount);
      await stakeManager.deposit({ value: amount });
      expect(await stakeManager.totalUnstaked()).to.be.eq(amount);

      expect(await stakeManager.startDelegation({ value: relayFee }))
        .emit(stakeManager, "TransferOut")
        .withArgs(amount.sub(smallAmount));
      expect(await stakeManager.totalUnstaked()).to.be.eq(smallAmount);
    });
  });

  describe("completeDelegation", () => {
    it("Fails when Invalid UUID is passed", async () => {});
    it("Fails when invoked again with stale UUID", async () => {});
    it("Should ", async () => {});
  });
});
