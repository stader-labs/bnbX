# BNBx Bot Operations Agent

## Supported Chains

- BSC

## Alerts

- BNBx-REWARD-CHANGE

  - Fired when Reward changes by more than 0.5 %
  - Severity is set to "High"
  - Type is set to "Info"
  - metadata: lastRewardAmount, curentRewardAmount

- BNBx-DAILY-REWARDS

  - Fired when Daily Rewards is not executed
  - Severity is set to "High"
  - Type is set to "Info"
  - metadata: lastRewardsTime

- BNBx-START-DELEGATION

  - Fired when StartDelegation is not executed for 36 hours
  - Severity is set to "High"
  - Type is set to "Info"
  - metadata: lastStartDelegationTime

- BNBx-COMPLETE-DELEGATION

  - Fired when CompleteDelegation is not executed for 12 hours past StartDelegation
  - Severity is set to "High"
  - Type is set to "Info"
  - metadata: lastStartDelegationTime, lastCompleteDelegationTime

- BNBx-START-UNDELEGATION

  - Fired when StartUndelegation is not executed for 7 days and 1 hours
  - Severity is set to "High"
  - Type is set to "Info"
  - metadata: lastStartUndelegationTime

- BNBx-UNDELEGATION-UPDATE

  - Fired when undelegationStarted is not executed for 12 hours past StartUndelegation
  - Severity is set to "High"
  - Type is set to "Info"
  - metadata: lastStartDelegationTime, lastUndelegationUpdateTime

- BNBx-COMPLETE-UNDELEGATION

  - Fired when CompleteUndelegation is not executed for 8 days and 12 hours past StartUndelegation
  - Severity is set to "High"
  - Type is set to "Info"
  - metadata: lastStartUndelegationTime, lastCompleteUndelegationTime
