# BNBx Bot Operations Agent

## Supported Chains

- BSC

## Alerts

- BNBx-DAILY-REWARDS

  - Fired when Daily Rewards is not executed
  - Severity is set to "Critical"
  - Type is set to "Info"
  - metadata: lastRewardsTime

- BNBx-START-DELEGATION

  - Fired when StartDelegation is not executed for 48 hours
  - Severity is set to "Critical"
  - Type is set to "Info"
  - metadata: lastStartDelegationTime

- BNBx-COMPLETE-DELEGATION

  - Fired when CompleteDelegation is not executed for 1 hour past StartDelegation
  - Severity is set to "Critical"
  - Type is set to "Info"
  - metadata: lastStartDelegationTime, lastCompleteDelegationTime

- BNBx-START-UNDELEGATION

  - Fired when StartUndelegation is not executed for 10 mins past its schedule time
  - Severity is set to "Critical"
  - Type is set to "Info"
  - metadata: lastStartUndelegationTime

- BNBx-UNDELEGATION-UPDATE

  - Fired when undelegationStarted is not executed for 30 Mins past StartUndelegation
  - Severity is set to "Critical"
  - Type is set to "Info"
  - metadata: lastStartDelegationTime, lastUndelegationUpdateTime

- BNBx-COMPLETE-UNDELEGATION

  - Fired when CompleteUndelegation is not executed for 7 days and 3 hours past StartUndelegation
  - Severity is set to "Critical"
  - Type is set to "Info"
  - metadata: lastStartUndelegationTime, lastCompleteUndelegationTime
