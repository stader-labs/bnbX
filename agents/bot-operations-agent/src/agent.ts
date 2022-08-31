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
  COMPLETE_UNDELEGATION_DELAY,
  COMPLETE_UNDELEGATION_FN,
  protocol,
  REWARD_CHANGE_BPS,
  REWARD_DELAY_HOURS,
  REWARD_EVENT,
  STAKE_MANAGER,
  START_DELEGATION_DELAY,
  START_DELEGATION_FN,
  START_UNDELEGATION_DELAY,
  START_UNDELEGATION_FN,
  TOTAL_BPS,
  UNDELEGATION_UPDATE_DELAY,
  UNDELEGATION_UPDATE_FN,
} from "./constants";

import { getHours } from "./utils";

let dailyRewardsFailed: boolean,
  lastRewardsTime: Date,
  lastRewardAmount: BigNumber;

let lastStartDelegationTime: Date, startDelegationFailed: boolean;
let lastCompleteDelegationTime: Date, completeDelegationFailed: boolean;

let lastStartUndelegationTime: Date, startUndelegationFailed: boolean;
let lastUndelegationUpdateTime: Date, undelegationUpdateFailed: boolean;
let lastCompleteUndelegationTime: Date, completeUndelegationFailed: boolean;

const handleTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = (
    await Promise.all([
      handleRewardTransaction(txEvent),
      handleStartDelegationTransaction(txEvent),
      handleCompleteDelegationTransaction(txEvent),
      handleStartUndelegationTransaction(txEvent),
      handleUndelegationUpdateTransaction(txEvent),
      handleCompleteUndelegationTransaction(txEvent),
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
            description: `Reward changed more than ${
              REWARD_CHANGE_BPS / TOTAL_BPS
            } %`,
            alertId: "BNBx-REWARD-CHANGE",
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
        alertId: "BNBx-DAILY-REWARDS",
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
        alertId: "BNBx-START-DELEGATION",
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
        description: `Complete Delegation not invoked since ${COMPLETE_DELEGATION_DELAY} Hours past last Start Delegation`,
        alertId: "BNBx-COMPLETE-DELEGATION",
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

const handleStartUndelegationTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];
  const startUndelegationInvocations = txEvent.filterFunction(
    START_UNDELEGATION_FN,
    STAKE_MANAGER
  );

  if (startUndelegationInvocations.length) {
    lastStartUndelegationTime = new Date();
    startUndelegationFailed = false;
    return findings;
  }

  if (!lastStartUndelegationTime) return findings;

  if (startUndelegationFailed) return findings;

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastStartUndelegationTime.getTime();
  const diffHours = getHours(diff);
  if (diffHours > START_UNDELEGATION_DELAY) {
    findings.push(
      Finding.fromObject({
        name: "Start Undelegation Failed",
        description: `Start Undelegation not invoked since ${START_UNDELEGATION_DELAY} Hours`,
        alertId: "BNBx-START-UNDELEGATION",
        protocol: protocol,
        severity: FindingSeverity.High,
        type: FindingType.Info,
        metadata: {
          lastStartUndelegationTime: lastStartUndelegationTime.toUTCString(),
        },
      })
    );
    startUndelegationFailed = true;
  }

  return findings;
};

const handleUndelegationUpdateTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];
  const UndelegationUpdateInvocations = txEvent.filterFunction(
    UNDELEGATION_UPDATE_FN,
    STAKE_MANAGER
  );

  if (UndelegationUpdateInvocations.length) {
    lastUndelegationUpdateTime = new Date();
    undelegationUpdateFailed = false;
    return findings;
  }

  if (!lastStartUndelegationTime || !lastUndelegationUpdateTime) {
    return findings;
  }

  if (startUndelegationFailed || undelegationUpdateFailed) return findings;

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastStartUndelegationTime.getTime();
  const undelegationUpdateDiff =
    currentTime.getTime() - lastUndelegationUpdateTime.getTime();

  const diffHours = getHours(diff);
  const undelegationUpdateDiffHours = getHours(undelegationUpdateDiff);

  if (
    diffHours > UNDELEGATION_UPDATE_DELAY &&
    undelegationUpdateDiffHours > diffHours
  ) {
    findings.push(
      Finding.fromObject({
        name: "Undelegation Update Failed",
        description: `Undelegation not invoked at Beacon Chain since ${UNDELEGATION_UPDATE_DELAY} Hours past last Start UnDelegation`,
        alertId: "BNBx-UNDELEGATION-UPDATE",
        protocol: protocol,
        severity: FindingSeverity.High,
        type: FindingType.Info,
        metadata: {
          lastStartUndelegationTime: lastStartUndelegationTime.toUTCString(),
          lastUndelegationUpdateTime: lastUndelegationUpdateTime.toUTCString(),
        },
      })
    );
    undelegationUpdateFailed = true;
  }

  return findings;
};

const handleCompleteUndelegationTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];
  const completeUndelegationInvocations = txEvent.filterFunction(
    COMPLETE_UNDELEGATION_FN,
    STAKE_MANAGER
  );

  if (completeUndelegationInvocations.length) {
    lastCompleteUndelegationTime = new Date();
    completeUndelegationFailed = false;
    return findings;
  }

  if (!lastStartUndelegationTime || !lastCompleteUndelegationTime) {
    return findings;
  }

  if (startUndelegationFailed || completeUndelegationFailed) return findings;

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastStartUndelegationTime.getTime();
  const compDiff =
    currentTime.getTime() - lastCompleteUndelegationTime.getTime();

  const diffHours = getHours(diff);
  const compDiffHours = getHours(compDiff);

  if (diffHours > COMPLETE_UNDELEGATION_DELAY && compDiffHours > diffHours) {
    findings.push(
      Finding.fromObject({
        name: "Complete Undelegation Failed",
        description: `Complete Undelegation not invoked since ${COMPLETE_UNDELEGATION_DELAY} Hours past last Start Undelegation`,
        alertId: "BNBx-COMPLETE-UNDELEGATION",
        protocol: protocol,
        severity: FindingSeverity.High,
        type: FindingType.Info,
        metadata: {
          lastStartUndelegationTime: lastStartUndelegationTime.toUTCString(),
          lastCompleteUndelegationTime:
            lastCompleteUndelegationTime.toUTCString(),
        },
      })
    );
    completeUndelegationFailed = true;
  }

  return findings;
};

export default {
  handleTransaction,
};
