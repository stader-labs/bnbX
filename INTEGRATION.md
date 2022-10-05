# Integration guide

## Stake BNB

```SOLIDITY
IStakeManager stakeManager = IStakeManager(STAKE_MANAGER_ADDRESS);
IStakeManager.deposit{value: msg.value}();
uint256 amountInBnbX = IBnbX(BNBX_ADDRESS).balanceOf(msg.sender);

emit StakeEvent(msg.sender, msg.value, amountInBnbX);
```

## Unstake BNB

```SOLIDITY
require(
    IBnbX(BNBX_ADDRESS).approve(STAKE_MANAGER_ADDRESS, amount),
    "Not approved"
);
IStakeManager stakeManager = IStakeManager(STAKE_MANAGER_ADDRESS);
IStakeManager.requestWithdraw(amount);

emit UnstakeEvent(msg.sender, amount);
```

## Claim BNB

```SOLIDITY
IStakeManager stakeManager = IStakeManager(STAKE_MANAGER_ADDRESS);
IStakeManager.claimWithdraw(_idx);
uint256 amount = address(msg.sender).balance;

emit ClaimEvent(msg.sender, amount);
```
