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
          name: "High BNBx Unstake",
          description: `High amount of BNBx unstaked: ${normalizedValue}`,
          alertId: "BNBx-2",
          severity: FindingSeverity.High,
          type: FindingType.Info,
          metadata: {
            _account,
            _amountInBnbX,
          },
        })
      );
    }
  });

  return findings;
};

export { handleTransaction };
