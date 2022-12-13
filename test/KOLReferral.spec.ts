import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { KOLReferral } from "../typechain";

describe("KOL referral Contract", () => {
  let deployer: SignerWithAddress;
  let admin: SignerWithAddress;
  let kol1: SignerWithAddress;
  let kol2: SignerWithAddress;
  let users: SignerWithAddress[];
  let kolContract: KOLReferral;

  beforeEach(async () => {
    [admin, kol1, kol2, ...users] = await ethers.getSigners();

    kolContract = await (
      await ethers.getContractFactory("KOLReferral")
    ).deploy(admin.address);
    await kolContract.deployed();
  });

  it("register a kol", async () => {
    let referralId1: string = "kol_1_ref_id";
    await kolContract.registerKOL(kol1.address, referralId1);

    expect(await kolContract.walletToReferralId(kol1.address)).be.eq(
      referralId1
    );
    expect(await kolContract.referralIdToWallet(referralId1)).be.eq(
      kol1.address
    );
  });

  it("store user info", async () => {
    let referralId1: string = "kol_1_ref_id";
    await kolContract.registerKOL(kol1.address, referralId1);

    let u1kolContract = kolContract.connect(users[0]);

    await u1kolContract.storeUserInfo(referralId1);

    expect(await kolContract.queryUserReferrer(users[0].address)).to.be.eq(
      kol1.address
    );

    const totalUsers = await kolContract.getTotalUsers();
    const { numUsers, userList } = await kolContract.getUserList(0, totalUsers);
    expect(userList[0]).to.be.eq(users[0].address);
    expect(numUsers).to.be.eq(1);
    expect(numUsers).to.be.eq(totalUsers);
  });
});
