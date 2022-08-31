import {
  ethers,
  Finding,
  FindingSeverity,
  FindingType,
  HandleTransaction,
  TransactionEvent,
} from "forta-agent";

import {
  BNBX_UNSTAKE_THRESHOLD,
  protocol,
  REQUEST_WITHDRAW_EVENT,
  STAKE_MANAGER,
} from "./constants";

const handleTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];

  // filter the transaction logs for BNBx unstake events
  const bnbxUnstakeEvents = txEvent.filterLog(
    REQUEST_WITHDRAW_EVENT,
    STAKE_MANAGER
  );

  bnbxUnstakeEvents.forEach((unstakeEvents) => {
    const { _account, _amountInBnbX } = unstakeEvents.args;

    const normalizedValue = ethers.utils.formatEther(_amountInBnbX);
    const minThreshold = ethers.utils.parseEther(BNBX_UNSTAKE_THRESHOLD);

    if (_amountInBnbX.gt(minThreshold)) {
      findings.push(
        Finding.fromObject({
          name: "Large BNBx Unstake",
          description: `Large amount of BNBx unstaked: ${normalizedValue}`,
          alertId: "BNBx-LARGE-UNSTAKE",
          protocol: protocol,
          severity: FindingSeverity.High,
          type: FindingType.Info,
          metadata: {
            account: _account,
            amountInBNBx: _amountInBnbX.toString(),
          },
        })
      );
    }
  });

  return findings;
};

export { handleTransaction };
