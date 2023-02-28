export const protocol = "BNBx Stader";
export const STAKE_MANAGER = "0x7276241a669489E4BBB76f63d2A43Bfe63080F2F";
export const REWARD_EVENT =
  "event Redelegate(uint256 _rewardsId, uint256 _amount)";
export const REWARD_DELAY_HOURS = 24;

export const START_DELEGATION_FN = "function startDelegation()";
export const START_DELEGATION_DELAY = 48;

export const COMPLETE_DELEGATION_FN =
  "function completeDelegation(uint256 _uuid)";
export const COMPLETE_DELEGATION_DELAY = 1;

export const START_UNDELEGATION_FN = "function startUndelegation()";
export const START_UNDELEGATION_DELAY = 168;
export const START_UNDELEGATION_DELAY_MINS = 10;

export const UNDELEGATION_UPDATE_FN =
  "function undelegationStarted(uint256 _uuid)";
export const UNDELEGATION_UPDATE_DELAY_MINS = 30;

export const COMPLETE_UNDELEGATION_FN =
  "function completeUndelegation(uint256 _uuid)";
export const COMPLETE_UNDELEGATION_DELAY = 171;
