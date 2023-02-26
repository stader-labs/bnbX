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
    findings.push(
      Finding.fromObject({
        name: "Proposal Scheduled",
        description: `Upgrade Proposal Scheduled. Timelock expires in ${upgradeEvents[0].args.delay.toString()} seconds`,
        alertId: "BNBX-TIMELOCK",
        protocol: protocol,
        severity: FindingSeverity.Info,
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
