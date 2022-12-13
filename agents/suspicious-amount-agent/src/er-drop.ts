import {
  BlockEvent,
  ethers,
  Finding,
  FindingSeverity,
  FindingType,
  getEthersProvider,
  HandleBlock,
} from "forta-agent";
import { protocol, STAKE_MANAGER } from "./constants";

import abis from "./abi";
import { BigNumber } from "ethers";

let lastER: BigNumber;

const handleBlock: HandleBlock = async (blockEvent: BlockEvent) => {
  const findings: Finding[] = [];

  const stakeManager = new ethers.Contract(
    STAKE_MANAGER,
    abis.StakeManager.abi,
    getEthersProvider()
  );
  const oneEther = ethers.utils.parseEther("1");
  const currentER: BigNumber = await stakeManager.convertBnbXToBnb(oneEther, {
    blockTag: blockEvent.blockNumber,
  });
  if (lastER && currentER.lt(lastER)) {
    findings.push(
      Finding.fromObject({
        name: "ER Drop",
        description: `Exchange Rate Dropped`,
        alertId: "BNBx-ER-DROP",
        protocol: protocol,
        severity: FindingSeverity.Critical,
        type: FindingType.Exploit,
        metadata: {
          lastER: lastER.toString(),
          currentER: currentER.toString(),
        },
      })
    );
  }

  lastER = currentER;
  return findings;
};

export { handleBlock };
