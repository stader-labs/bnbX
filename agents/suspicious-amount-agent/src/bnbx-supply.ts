import {
  BlockEvent,
  ethers,
  Finding,
  FindingSeverity,
  FindingType,
  getEthersProvider,
  HandleBlock,
} from "forta-agent";
import {
  BNBx,
  BNBX_SUPPLY_CHANGE_HOURS,
  BNBX_SUPPLY_CHANGE_PCT,
  protocol,
  STAKE_MANAGER,
} from "./constants";

import abis from "./abi";
import { BigNumber } from "ethers";
import { getHours } from "./utils";

let lastSupply: BigNumber, lastSupplyTime: Date;
let supplyMismatch: boolean;

const handleBlock: HandleBlock = async (blockEvent: BlockEvent) => {
  const findings: Finding[] = [];

  const bnbX = new ethers.Contract(BNBx, abis.BnbX.abi, getEthersProvider());
  const stakeManager = new ethers.Contract(
    STAKE_MANAGER,
    abis.StakeManager.abi,
    getEthersProvider()
  );

  const oneEther = ethers.utils.parseEther("1");
  const currentER: BigNumber = await stakeManager.convertBnbXToBnb(oneEther);
  const totalPooledBnb: BigNumber = await stakeManager.getTotalPooledBnb();
  const currentSupply: BigNumber = await bnbX.totalSupply();

  if (
    currentER
      .mul(currentSupply)
      .div(oneEther)
      .sub(totalPooledBnb)
      .abs()
      .div(oneEther)
      .gt(1)
  ) {
    if (!supplyMismatch) {
      findings.push(
        Finding.fromObject({
          name: "BNBx Supply Mis-Match",
          description: `BNBx, ER and TotalPooledBnb doesn't match`,
          alertId: "BNBx-SUPPLY-MISMATCH",
          protocol: protocol,
          severity: FindingSeverity.Critical,
          type: FindingType.Exploit,
          metadata: {
            currentER: currentER.toString(),
            totalPooledBnb: totalPooledBnb.toString(),
            currentSupply: currentSupply.toString(),
          },
        })
      );
      supplyMismatch = true;
    }
  } else {
    supplyMismatch = false;
  }

  const currentSupplyTime: Date = new Date();
  if (!lastSupply) {
    lastSupply = currentSupply;
    lastSupplyTime = currentSupplyTime;
    return findings;
  }
  const diffHours = getHours(
    currentSupplyTime.getTime() - lastSupplyTime.getTime()
  );
  if (diffHours > BNBX_SUPPLY_CHANGE_HOURS) {
    if (
      currentSupply
        .sub(lastSupply)
        .abs()
        .gt(lastSupply.mul(BNBX_SUPPLY_CHANGE_PCT).div(100))
    ) {
      findings.push(
        Finding.fromObject({
          name: "BNBx Supply Change",
          description: `BNBx Total Supply changed more than ${BNBX_SUPPLY_CHANGE_PCT} %`,
          alertId: "BNBx-SUPPLY-CHANGE",
          protocol: protocol,
          severity: FindingSeverity.High,
          type: FindingType.Suspicious,
          metadata: {
            lastSupply: lastSupply.toString(),
            currentSupply: currentSupply.toString(),
          },
        })
      );
    }

    lastSupplyTime = currentSupplyTime;
    lastSupply = currentSupply;
  }

  return findings;
};

export { handleBlock };
