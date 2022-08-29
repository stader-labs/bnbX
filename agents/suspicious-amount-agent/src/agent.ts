import { Finding, HandleTransaction, TransactionEvent } from "forta-agent";

import * as suspiciousMint from "./suspicious-mint";
import * as suspiciousWithdraw from "./suspicious-withdraw";
import * as suspiciousRewards from "./suspicious-rewards";

const handleTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = (
    await Promise.all([
      suspiciousMint.handleTransaction(txEvent),
      suspiciousWithdraw.handleTransaction(txEvent),
      suspiciousRewards.handleTransaction(txEvent),
    ])
  ).flat();

  return findings;
};

// const handleBlock: HandleBlock = async (blockEvent: BlockEvent) => {
//   const findings: Finding[] = [];
//   // detect some block condition
//   return findings;
// }

export default {
  handleTransaction,
  // handleBlock
};
