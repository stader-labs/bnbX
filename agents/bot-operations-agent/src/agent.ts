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
  REWARD_CHANGE_PCT_THRESHOLD,
  REWARD_DELAY_HOURS,
  REWARD_EVENT,
  STAKE_MANAGER,
} from "./constants";

import { getHours } from "./utils";

let dailyRewardsAlerted: boolean,
  lastRewardsTime: Date,
  lastRewardAmount: BigNumber;

const handleTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = (
    await Promise.all([handleRewardTransaction(txEvent)])
  ).flat();

  return findings;
};

const handleRewardTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];
  const bnbxRewardEvents = txEvent.filterLog(REWARD_EVENT, STAKE_MANAGER);

  if (bnbxRewardEvents.length) {
    const { _amount } = bnbxRewardEvents[0].args;
    if (lastRewardsTime) {
      if (
        lastRewardAmount
          .sub(_amount)
          .abs()
          .gt(lastRewardAmount.mul(REWARD_CHANGE_PCT_THRESHOLD).div(100))
      ) {
        findings.push(
          Finding.fromObject({
            name: "Significant Reward Change",
            description: `Reward changed more than ${REWARD_CHANGE_PCT_THRESHOLD} %`,
            alertId: "BNBx-5",
            protocol: protocol,
            severity: FindingSeverity.High,
            type: FindingType.Info,
            metadata: {
              lastRewardAmount: lastRewardAmount.toString(),
              cuurentRewardAmount: _amount.toString(),
            },
          })
        );
      }
    }

    lastRewardsTime = new Date();
    dailyRewardsAlerted = false;
    lastRewardAmount = _amount;

    return findings;
  }

  if (!lastRewardsTime) {
    return findings;
  }

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastRewardsTime.getTime();
  const diffHours = getHours(diff);
  if (diffHours > REWARD_DELAY_HOURS && !dailyRewardsAlerted) {
    findings.push(
      Finding.fromObject({
        name: "Rewards Delay",
        description: `Rewards not Autocompunded`,
        alertId: "BNBx-6",
        protocol: protocol,
        severity: FindingSeverity.High,
        type: FindingType.Info,
        metadata: {
          lastRewardsTime: lastRewardsTime.toUTCString(),
        },
      })
    );
    dailyRewardsAlerted = true;
  }

  return findings;
};

export default {
  handleTransaction,
};
