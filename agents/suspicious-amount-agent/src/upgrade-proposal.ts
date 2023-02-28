import {
  Finding,
  FindingSeverity,
  FindingType,
  HandleTransaction,
  TransactionEvent,
} from "forta-agent";
import {
  protocol,
  PROXY_ADMIN,
  TIMELOCK_CONTRACT,
  TIMELOCK_SCHEDULE_EVENT,
} from "./constants";
import { getHours, getMins } from "./utils";

const handleTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];

  const upgradeEvents = txEvent
    .filterLog(TIMELOCK_SCHEDULE_EVENT, TIMELOCK_CONTRACT)
    .filter((transferEvent) => {
      const { target } = transferEvent.args;
      return target === PROXY_ADMIN;
    });

  if (upgradeEvents.length) {
    const delayInMiliSecs =
      parseInt(upgradeEvents[0].args.delay.toString()) * 1000;
    findings.push(
      Finding.fromObject({
        name: "Proposal Scheduled",
        description: `Upgrade Proposal Scheduled. Timelock expires in ${getHours(
          delayInMiliSecs
        )} hours ${getMins(delayInMiliSecs) % 60} mins`,
        alertId: "BNBX-TIMELOCK",
        protocol: protocol,
        severity: FindingSeverity.High,
        type: FindingType.Info,
        metadata: {
          delay: upgradeEvents[0].args.delay.toString(),
        },
        addresses: [TIMELOCK_CONTRACT, PROXY_ADMIN],
      })
    );
  }

  return findings;
};

export { handleTransaction };
