import { BigNumber } from "ethers";
import {
  Finding,
  FindingSeverity,
  FindingType,
  HandleTransaction,
  TransactionEvent,
} from "forta-agent";
import {
  COMPLETE_DELEGATION_DELAY,
  COMPLETE_DELEGATION_FN,
  protocol,
  REWARD_CHANGE_BPS,
  REWARD_DELAY_HOURS,
  REWARD_EVENT,
  STAKE_MANAGER,
  START_DELEGATION_DELAY,
  START_DELEGATION_FN,
  TOTAL_BPS,
} from "./constants";

import { getHours } from "./utils";

let dailyRewardsFailed: boolean,
  lastRewardsTime: Date,
  lastRewardAmount: BigNumber;

let lastStartDelegationTime: Date, startDelegationFailed: boolean;
let lastCompleteDelegationTime: Date, completeDelegationFailed: boolean;

const handleTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = (
    await Promise.all([
      handleRewardTransaction(txEvent),
      handleStartDelegationTransaction(txEvent),
      handleCompleteDelegationTransaction(txEvent),
    ])
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
          .gt(lastRewardAmount.mul(REWARD_CHANGE_BPS).div(TOTAL_BPS))
      ) {
        findings.push(
          Finding.fromObject({
            name: "Significant Reward Change",
            description: `Reward changed more than ${REWARD_CHANGE_BPS} %`,
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
    dailyRewardsFailed = false;
    lastRewardAmount = _amount;

    return findings;
  }

  if (!lastRewardsTime) return findings;

  if (dailyRewardsFailed) return findings;

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastRewardsTime.getTime();
  const diffHours = getHours(diff);
  if (diffHours > REWARD_DELAY_HOURS) {
    findings.push(
      Finding.fromObject({
        name: "Daily Rewards Failed",
        description: `Daily Rewards Autocompund not invoked since ${REWARD_DELAY_HOURS} Hours`,
        alertId: "BNBx-6",
        protocol: protocol,
        severity: FindingSeverity.High,
        type: FindingType.Info,
        metadata: {
          lastRewardsTime: lastRewardsTime.toUTCString(),
        },
      })
    );
    dailyRewardsFailed = true;
  }

  return findings;
};

const handleStartDelegationTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];
  const startDelegationInvocations = txEvent.filterFunction(
    START_DELEGATION_FN,
    STAKE_MANAGER
  );

  if (startDelegationInvocations.length) {
    lastStartDelegationTime = new Date();
    startDelegationFailed = false;
    return findings;
  }

  if (!lastStartDelegationTime) return findings;

  if (startDelegationFailed) return findings;

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastStartDelegationTime.getTime();
  const diffHours = getHours(diff);
  if (diffHours > START_DELEGATION_DELAY) {
    findings.push(
      Finding.fromObject({
        name: "Start Delegation Failed",
        description: `Start Delegation not invoked since ${START_DELEGATION_DELAY} Hours`,
        alertId: "BNBx-7",
        protocol: protocol,
        severity: FindingSeverity.High,
        type: FindingType.Info,
        metadata: {
          lastStartDelegationTime: lastStartDelegationTime.toUTCString(),
        },
      })
    );
    startDelegationFailed = true;
  }

  return findings;
};

const handleCompleteDelegationTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];
  const completeDelegationInvocations = txEvent.filterFunction(
    COMPLETE_DELEGATION_FN,
    STAKE_MANAGER
  );

  if (completeDelegationInvocations.length) {
    lastCompleteDelegationTime = new Date();
    completeDelegationFailed = false;
    return findings;
  }

  if (!lastStartDelegationTime || !lastCompleteDelegationTime) {
    return findings;
  }

  if (startDelegationFailed || completeDelegationFailed) return findings;

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastStartDelegationTime.getTime();
  const compDiff = currentTime.getTime() - lastCompleteDelegationTime.getTime();

  const diffHours = getHours(diff);
  const compDiffHours = getHours(compDiff);

  if (diffHours > COMPLETE_DELEGATION_DELAY && compDiffHours > diffHours) {
    findings.push(
      Finding.fromObject({
        name: "Complete Delegation Failed",
        description: `Complete Delegation not invoked since ${COMPLETE_DELEGATION_DELAY} Hours of last Start Delegation`,
        alertId: "BNBx-8",
        protocol: protocol,
        severity: FindingSeverity.High,
        type: FindingType.Info,
        metadata: {
          lastStartDelegationTime: lastStartDelegationTime.toUTCString(),
          lastCompleteDelegationTime: lastCompleteDelegationTime.toUTCString(),
        },
      })
    );
    completeDelegationFailed = true;
  }

  return findings;
};

export default {
  handleTransaction,
};
