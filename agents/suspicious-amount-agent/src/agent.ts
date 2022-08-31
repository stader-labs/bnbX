import {
  BlockEvent,
  Finding,
  HandleBlock,
  HandleTransaction,
  TransactionEvent,
} from "forta-agent";

import * as suspiciousMint from "./suspicious-mint";
import * as suspiciousWithdraw from "./suspicious-withdraw";
import * as suspiciousRewards from "./suspicious-rewards";
import * as erDrop from "./er-drop";
import * as supplyChange from "./bnbx-supply";

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

const handleBlock: HandleBlock = async (blockEvent: BlockEvent) => {
  const findings: Finding[] = (
    await Promise.all([
      erDrop.handleBlock(blockEvent),
      supplyChange.handleBlock(blockEvent),
    ])
  ).flat();

  return findings;
};

export default {
  handleTransaction,
  handleBlock,
};
