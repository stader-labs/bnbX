import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect, use } from "chai";
import { BigNumber, BigNumberish } from "ethers";
import { ethers, upgrades } from "hardhat";
import { BnbX, TokenHubMock, StakeManager, IBnbX } from "../typechain";

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

  let relayFee: BigNumber;

  let uStakeManager: StakeManager;
  let bStakeManager: StakeManager;

  let bnbXApprove: (
    signer: SignerWithAddress,
    amount: BigNumberish
  ) => Promise<void>;

  before(() => {
    bnbXApprove = async (signer, amount) => {
      const signerBnbX = bnbX.connect(signer);
      await signerBnbX.approve(stakeManager.address, amount);
    };
  });

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
    relayFee = await tokenHub.relayFee();

    uStakeManager = stakeManager.connect(user);
    bStakeManager = stakeManager.connect(bot);
  });

  it("Should convert Bnb to BnbX properly", async () => {
    const amount = BigNumber.from("700");
    const amountInBnbX = await uStakeManager.convertBnbToBnbX(amount);
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
    await uStakeManager.deposit({ value: amount });
    expect(await uStakeManager.totalNotStaked()).to.be.eq(amount.add(amount));
    // user bnbX balance should increase
    expect(await bnbX.balanceOf(user.address)).to.be.eq(amount);
  });

  describe("startDelegation", () => {
    it("Fails when invoked by anyone except bot", async () => {
      await expect(uStakeManager.startDelegation()).to.be.revertedWith(
        "is missing role"
      );
    });

    it("Fails if less or no relayFee is provided", async () => {
      // provided 0 relayFee
      await expect(bStakeManager.startDelegation()).to.be.revertedWith(
        "Require More Relay Fee, Check getTokenHubRelayFee"
      );

      await expect(
        bStakeManager.startDelegation({
          value: ethers.utils.parseEther("0.001"),
        })
      ).to.be.revertedWith("Require More Relay Fee, Check getTokenHubRelayFee");

      await expect(
        bStakeManager.startDelegation({ value: relayFee })
      ).to.be.revertedWith("Insufficient Deposit Amount");
    });

    it("Fails when totalNotStaked funds is less than 1e10", async () => {
      const amount = BigNumber.from("300");
      const zeroBalance = BigNumber.from("0");

      expect(await stakeManager.totalNotStaked()).to.be.eq(zeroBalance);
      await expect(
        bStakeManager.startDelegation({ value: relayFee })
      ).to.be.revertedWith("Insufficient Deposit Amount");

      await uStakeManager.deposit({ value: amount });
      expect(await stakeManager.totalNotStaked()).to.be.eq(amount);

      await expect(
        bStakeManager.startDelegation({ value: relayFee })
      ).to.be.revertedWith("Insufficient Deposit Amount");
    });

    it("Should transfer amount in multiples of 1e10", async () => {
      const smallAmount = BigNumber.from("300");
      let amount = ethers.utils.parseEther("0.1");
      amount = amount.add(smallAmount);
      await uStakeManager.deposit({ value: amount });
      expect(await stakeManager.totalNotStaked()).to.be.eq(amount);

      expect(await bStakeManager.startDelegation({ value: relayFee }))
        .emit(stakeManager, "TransferOut")
        .withArgs(amount.sub(smallAmount));
      expect(await stakeManager.totalDeposited()).to.be.eq(amount);
      expect(await stakeManager.totalNotStaked()).to.be.eq(smallAmount);
      expect(await stakeManager.totalOutBuffer()).to.be.eq(
        amount.sub(smallAmount)
      );

      const botDelegateRequest = await bStakeManager.getBotDelegateRequest(0);
      expect(botDelegateRequest.endTime).to.be.eq(0);
      expect(botDelegateRequest.amount).to.be.eq(amount.sub(smallAmount));
    });
  });

  describe("completeDelegation", () => {
    it("Fails when invoked by anyone except bot", async () => {
      await expect(uStakeManager.completeDelegation(0)).to.be.revertedWith(
        "is missing role"
      );
    });

    it("Fails when Invalid UUID is passed", async () => {
      await expect(bStakeManager.completeDelegation(0)).to.be.revertedWith(
        "Invalid UUID"
      );

      const amount = ethers.utils.parseEther("0.1");
      await uStakeManager.deposit({ value: amount });
      await bStakeManager.startDelegation({ value: relayFee });
      await expect(bStakeManager.completeDelegation(1)).to.be.revertedWith(
        "Invalid UUID"
      );
      await expect(bStakeManager.completeDelegation(2)).to.be.revertedWith(
        "Invalid UUID"
      );
      await expect(bStakeManager.completeDelegation(126)).to.be.revertedWith(
        "Invalid UUID"
      );
    });

    it("Should succeed when correct UUID is passed", async () => {
      const amount = ethers.utils.parseEther("0.1");
      await uStakeManager.deposit({ value: amount });
      await bStakeManager.startDelegation({ value: relayFee });
      expect(await bStakeManager.completeDelegation(0))
        .emit(stakeManager, "Delegate")
        .withArgs(0, amount);
      expect(await stakeManager.totalDeposited()).to.be.eq(amount);
      expect(await stakeManager.totalOutBuffer()).to.be.eq(0);

      const botDelegateRequest = await bStakeManager.getBotDelegateRequest(0);
      expect(botDelegateRequest.endTime).to.be.not.eq(0);
    });

    it("Fails when invoked again with stale UUID", async () => {
      const amount = ethers.utils.parseEther("0.1");
      await uStakeManager.deposit({ value: amount });
      await bStakeManager.startDelegation({ value: relayFee });
      await bStakeManager.completeDelegation(0);
      await expect(bStakeManager.completeDelegation(0)).to.be.revertedWith(
        "Invalid UUID"
      );
    });
  });

  describe("requestWithdraw", () => {
    beforeEach(async () => {});
    it("Fails if user doesn't have BnbX", async () => {
      await expect(uStakeManager.requestWithdraw(0)).to.be.revertedWith(
        "Invalid Amount"
      );
    });
    it("Fails if user has not approved the StakeManager Contract for spending BnbX", async () => {
      await expect(
        uStakeManager.requestWithdraw(ethers.utils.parseEther("1"))
      ).to.be.revertedWith("ERC20: insufficient allowance");
    });
    it("Fails if user requests to withdraw more Bnb than eligible", async () => {
      const amount = ethers.utils.parseEther("2");
      await uStakeManager.deposit({ value: amount });

      await bStakeManager.startDelegation({ value: relayFee });
      await bStakeManager.completeDelegation(0);

      await bnbXApprove(user, amount.add(amount)); // Just to provide more allowance
      await expect(
        uStakeManager.requestWithdraw(ethers.utils.parseEther("3"))
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });

    it("Fails if user requests to withdraw before it is actually staked at Beacon Chain", async () => {
      const amount = ethers.utils.parseEther("2");
      await uStakeManager.deposit({ value: amount });
      await bnbXApprove(user, amount);
      await expect(
        uStakeManager.requestWithdraw(ethers.utils.parseEther("1"))
      ).to.be.revertedWith("Not enough BNB to withdraw");

      await bStakeManager.startDelegation({ value: relayFee });
      await expect(
        uStakeManager.requestWithdraw(ethers.utils.parseEther("1"))
      ).to.be.revertedWith("Not enough BNB to withdraw");
    });

    it("Should successfully raise withdraw request", async () => {
      const amount = ethers.utils.parseEther("2");
      const withdrawAmount = ethers.utils.parseEther("1");

      await uStakeManager.deposit({ value: amount });

      await bStakeManager.startDelegation({ value: relayFee });
      await bStakeManager.completeDelegation(0);

      let userRequests = await stakeManager.getUserWithdrawalRequests(
        user.address
      );
      expect(userRequests.length).to.be.eq(0);

      await bnbXApprove(user, amount);
      await expect(uStakeManager.requestWithdraw(withdrawAmount))
        .emit(stakeManager, "RequestWithdraw")
        .withArgs(user.address, withdrawAmount, withdrawAmount);

      expect(await bnbX.balanceOf(stakeManager.address)).to.be.eq(
        withdrawAmount
      );
      expect(await stakeManager.totalBnbToWithdraw()).to.be.eq(withdrawAmount);
      expect(await stakeManager.totalBnbXToBurn()).to.be.eq(withdrawAmount);
      userRequests = await stakeManager.getUserWithdrawalRequests(user.address);
      expect(userRequests.length).to.be.eq(1);
    });
  });

  describe("startUndelegation", () => {
    it("Fails when invoked by anyone except bot", async () => {
      await expect(uStakeManager.startUndelegation()).to.be.revertedWith(
        "is missing role"
      );
    });

    it("Fails when no withdraw requests", async () => {
      await expect(bStakeManager.startUndelegation()).to.be.revertedWith(
        "Insufficient Withdraw Amount"
      );
    });

    it("Should successfully start undelegation after user requests withdraw", async () => {
      const amount = ethers.utils.parseEther("2");
      const withdrawAmount = ethers.utils.parseEther("1");

      await uStakeManager.deposit({ value: amount });

      await bStakeManager.startDelegation({ value: relayFee });
      await bStakeManager.completeDelegation(0);

      await bnbXApprove(user, amount);
      await uStakeManager.requestWithdraw(withdrawAmount);
      expect(await bnbX.balanceOf(stakeManager.address)).to.be.eq(
        withdrawAmount
      );

      await bStakeManager.startUndelegation();
      expect(await stakeManager.totalBnbToWithdraw()).to.be.eq(0);
      expect(await stakeManager.totalBnbXToBurn()).to.be.eq(0);
      expect(await bnbX.balanceOf(stakeManager.address)).to.be.eq(0);

      const botUndelegateRequest = await bStakeManager.getBotUndelegateRequest(
        0
      );
      expect(botUndelegateRequest.amount).to.be.eq(withdrawAmount);
      expect(botUndelegateRequest.endTime).to.be.eq(0);
    });
  });

  describe("completeUndelegation", () => {
    it("Fails when invoked by anyone except bot", async () => {
      await expect(uStakeManager.completeUndelegation(0)).to.be.revertedWith(
        "is missing role"
      );
    });

    it("Fails when bot has not started Undelegation", async () => {
      await expect(bStakeManager.completeUndelegation(0)).to.be.revertedWith(
        "Invalid UUID"
      );

      await expect(bStakeManager.completeUndelegation(1)).to.be.revertedWith(
        "Invalid UUID"
      );
    });

    it("Fails when invalid UUID is passed", async () => {
      const amount = ethers.utils.parseEther("2");
      const withdrawAmount = ethers.utils.parseEther("1");
      await uStakeManager.deposit({ value: amount });
      await bStakeManager.startDelegation({ value: relayFee });
      await bStakeManager.completeDelegation(0);
      await bnbXApprove(user, amount);
      await uStakeManager.requestWithdraw(withdrawAmount);
      await bStakeManager.startUndelegation();

      await expect(bStakeManager.completeUndelegation(1)).to.be.revertedWith(
        "Invalid UUID"
      );

      await expect(bStakeManager.completeUndelegation(4)).to.be.revertedWith(
        "Invalid UUID"
      );
    });

    it("Fails when incorrect amount of passed while invoking", async () => {
      const amount = ethers.utils.parseEther("2");
      const withdrawAmount = ethers.utils.parseEther("1");
      await uStakeManager.deposit({ value: amount });
      await bStakeManager.startDelegation({ value: relayFee });
      await bStakeManager.completeDelegation(0);
      await bnbXApprove(user, amount);
      await uStakeManager.requestWithdraw(withdrawAmount);
      await bStakeManager.startUndelegation();

      await expect(bStakeManager.completeUndelegation(0)).to.be.revertedWith(
        "Insufficient Fund"
      );

      await expect(
        bStakeManager.completeUndelegation(0, {
          value: withdrawAmount.sub(500),
        })
      ).to.be.revertedWith("Insufficient Fund");
    });

    it("Should successfully complete Undelegation", async () => {
      const amount = ethers.utils.parseEther("2");
      const withdrawAmount = ethers.utils.parseEther("1");
      await uStakeManager.deposit({ value: amount });
      await bStakeManager.startDelegation({ value: relayFee });
      await bStakeManager.completeDelegation(0);
      await bnbXApprove(user, amount);
      await uStakeManager.requestWithdraw(withdrawAmount);
      await bStakeManager.startUndelegation();

      await expect(
        bStakeManager.completeUndelegation(0, { value: withdrawAmount })
      )
        .emit(stakeManager, "Undelegate")
        .withArgs(0, withdrawAmount);

      const botUndelegateRequest = await bStakeManager.getBotUndelegateRequest(
        0
      );
      expect(botUndelegateRequest.endTime).to.be.not.eq(0);
    });
  });

  describe("claimWithdraw", () => {
    it("Fails when user attempts to claim without raising a request", async () => {
      await expect(uStakeManager.claimWithdraw(0)).to.be.revertedWith(
        "Invalid index"
      );
    });

    it("Fails when user claims with a invalid `_idx`", async () => {
      const amount = ethers.utils.parseEther("2");
      const withdrawAmount = ethers.utils.parseEther("1");
      await uStakeManager.deposit({ value: amount });
      await bStakeManager.startDelegation({ value: relayFee });
      await bStakeManager.completeDelegation(0);
      await bnbXApprove(user, amount);
      await uStakeManager.requestWithdraw(withdrawAmount);

      await expect(uStakeManager.claimWithdraw(1)).to.be.revertedWith(
        "Invalid index"
      );
      await expect(uStakeManager.claimWithdraw(2)).to.be.revertedWith(
        "Invalid index"
      );
      await expect(uStakeManager.claimWithdraw(41)).to.be.revertedWith(
        "Invalid index"
      );
    });

    it("Fails when user user's fund is not ready to claim", async () => {
      const amount = ethers.utils.parseEther("2");
      const withdrawAmount = ethers.utils.parseEther("1");
      await uStakeManager.deposit({ value: amount });
      await bStakeManager.startDelegation({ value: relayFee });
      await bStakeManager.completeDelegation(0);
      await bnbXApprove(user, amount);
      await uStakeManager.requestWithdraw(withdrawAmount);

      await expect(uStakeManager.claimWithdraw(0)).to.be.revertedWith(
        "Not able to claim yet"
      );

      await bStakeManager.startUndelegation();
      await expect(uStakeManager.claimWithdraw(0)).to.be.revertedWith(
        "Not able to claim yet"
      );
    });

    it("Should successfully be able to claim after raising withdraw request", async () => {
      const amount = ethers.utils.parseEther("2");
      const withdrawAmount = ethers.utils.parseEther("1");
      await uStakeManager.deposit({ value: amount });
      await bStakeManager.startDelegation({ value: relayFee });
      await bStakeManager.completeDelegation(0);
      await bnbXApprove(user, amount);
      await uStakeManager.requestWithdraw(withdrawAmount);
      await bStakeManager.startUndelegation();
      await bStakeManager.completeUndelegation(0, { value: withdrawAmount });

      const userBalanceBeforeClaim = await user.getBalance();
      let userRequests = await uStakeManager.getUserWithdrawalRequests(
        user.address
      );
      expect(userRequests.length).to.be.eq(1);

      await expect(uStakeManager.claimWithdraw(0))
        .emit(stakeManager, "ClaimWithdrawal")
        .withArgs(user.address, 0, withdrawAmount);

      const userBalanceAfterClaim = await user.getBalance();
      // eslint-disable-next-line no-unused-expressions
      expect(userBalanceAfterClaim.sub(userBalanceBeforeClaim).isNegative()).to
        .be.false;

      userRequests = await uStakeManager.getUserWithdrawalRequests(
        user.address
      );
      expect(userRequests.length).to.be.eq(0);
    });
  });

  describe("Miscellaneous", () => {
    it("post-increment", async () => {
      let value = 1;
      const currentValue = value++;
      const incrementedValue = value;

      expect(currentValue).to.be.eq(1);
      expect(incrementedValue).to.be.eq(2);
    });
  });
});
