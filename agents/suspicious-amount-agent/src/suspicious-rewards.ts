import { BigNumber } from "ethers";
import {
  Finding,
  FindingSeverity,
  FindingType,
  HandleTransaction,
  TransactionEvent,
} from "forta-agent";
import {
  protocol,
  REWARD_CHANGE_PCT,
  REWARD_EVENT,
  STAKE_MANAGER,
} from "./constants";

let lastRewardAmount: BigNumber;

const handleTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];

  const bnbxRewardEvents = txEvent.filterLog(REWARD_EVENT, STAKE_MANAGER);

  bnbxRewardEvents.forEach((rewardEvents) => {
    const { _amount } = rewardEvents.args;
    if (
      lastRewardAmount &&
      lastRewardAmount
        .sub(_amount)
        .abs()
        .gt(lastRewardAmount.mul(REWARD_CHANGE_PCT).div(100))
    ) {
      findings.push(
        Finding.fromObject({
          name: "Significant Reward Change",
          description: `Reward changed more than ${REWARD_CHANGE_PCT} %`,
          alertId: "BNBx-REWARD-CHANGE",
          protocol: protocol,
          severity: FindingSeverity.Medium,
          type: FindingType.Info,
          metadata: {
            lastRewardAmount: lastRewardAmount.toString(),
            cuurentRewardAmount: _amount.toString(),
          },
        })
      );
    }

    lastRewardAmount = _amount;
  });

  return findings;
};

export { handleTransaction };
