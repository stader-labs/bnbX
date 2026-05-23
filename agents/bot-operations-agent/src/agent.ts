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
  REWARD_DELAY_HOURS,
  REWARD_EVENT,
  STAKE_MANAGER,
  START_DELEGATION_DELAY,
  START_DELEGATION_FN,
  START_UNDELEGATION_DELAY,
  START_UNDELEGATION_DELAY_MINS,
  START_UNDELEGATION_FN,
  UNDELEGATION_UPDATE_DELAY_MINS,
  UNDELEGATION_UPDATE_FN,
} from "./constants";

import { getHours, getMins } from "./utils";

let dailyRewardsFailed: boolean, lastRewardsTime: Date;

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
    lastRewardsTime = new Date();
    dailyRewardsFailed = false;
    return [];
  }

  if (!lastRewardsTime) return [];

  if (dailyRewardsFailed) return [];

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastRewardsTime.getTime();
  const diffHours = getHours(diff);
  if (diffHours > REWARD_DELAY_HOURS) {
    findings.push(
      Finding.fromObject({
        name: "Daily Rewards Failed",
        description: `Rewards Autocompound not invoked since ${REWARD_DELAY_HOURS} Hours`,
        alertId: "BNBx-DAILY-REWARDS",
        protocol: protocol,
        severity: FindingSeverity.Critical,
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

  // found startDelegation -> no alert
  if (startDelegationInvocations.length) {
    lastStartDelegationTime = new Date();
    startDelegationFailed = false;
    return [];
  }

  // startDelegation not invoked since forta bot deployment -> no alert
  if (!lastStartDelegationTime) return [];

  // already alerted earlier -> repeated alert will make channel noisy
  if (startDelegationFailed) return [];

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
        severity: FindingSeverity.Critical,
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
    return [];
  }

  if (!lastStartDelegationTime || !lastCompleteDelegationTime) {
    return [];
  }

  if (startDelegationFailed || completeDelegationFailed) return [];

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastStartDelegationTime.getTime();
  const diffHours = getHours(diff);

  if (
    diffHours >= COMPLETE_DELEGATION_DELAY &&
    lastStartDelegationTime.getTime() > lastCompleteDelegationTime.getTime()
  ) {
    findings.push(
      Finding.fromObject({
        name: "Complete Delegation Failed",
        description: `Complete Delegation not invoked since ${COMPLETE_DELEGATION_DELAY} Hour past last Start Delegation`,
        alertId: "BNBx-COMPLETE-DELEGATION",
        protocol: protocol,
        severity: FindingSeverity.Critical,
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
    return [];
  }

  if (!lastStartUndelegationTime) return [];

  if (startUndelegationFailed) return [];

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastStartUndelegationTime.getTime();
  const diffHours = getHours(diff);
  const diffMins = getMins(diff);

  if (
    diffHours >= START_UNDELEGATION_DELAY &&
    diffMins >= START_UNDELEGATION_DELAY_MINS
  ) {
    findings.push(
      Finding.fromObject({
        name: "Start Undelegation Failed",
        description: `Start Undelegation not invoked ${START_UNDELEGATION_DELAY_MINS} Mins since its schedule time`,
        alertId: "BNBx-START-UNDELEGATION",
        protocol: protocol,
        severity: FindingSeverity.Critical,
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
    return [];
  }

  if (!lastStartUndelegationTime || !lastUndelegationUpdateTime) {
    return [];
  }

  if (startUndelegationFailed || undelegationUpdateFailed) return [];

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastStartUndelegationTime.getTime();
  const diffMins = getMins(diff);

  if (
    diffMins >= UNDELEGATION_UPDATE_DELAY_MINS &&
    lastStartUndelegationTime.getTime() > lastUndelegationUpdateTime.getTime()
  ) {
    findings.push(
      Finding.fromObject({
        name: "Undelegation Update Failed",
        description: `Undelegation not invoked at Beacon Chain since ${UNDELEGATION_UPDATE_DELAY_MINS} Mins past last Start UnDelegation`,
        alertId: "BNBx-UNDELEGATION-UPDATE",
        protocol: protocol,
        severity: FindingSeverity.Critical,
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
    return [];
  }

  if (!lastStartUndelegationTime || !lastCompleteUndelegationTime) {
    return [];
  }

  if (startUndelegationFailed || completeUndelegationFailed) return [];

  const currentTime = new Date();
  const diff = currentTime.getTime() - lastStartUndelegationTime.getTime();
  const diffHours = getHours(diff);

  if (
    diffHours >= COMPLETE_UNDELEGATION_DELAY &&
    lastStartUndelegationTime.getTime() > lastCompleteUndelegationTime.getTime()
  ) {
    findings.push(
      Finding.fromObject({
        name: "Complete Undelegation Failed",
        description: `Complete Undelegation not invoked since ${COMPLETE_UNDELEGATION_DELAY} Hours past last Start Undelegation`,
        alertId: "BNBx-COMPLETE-UNDELEGATION",
        protocol: protocol,
        severity: FindingSeverity.Critical,
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
