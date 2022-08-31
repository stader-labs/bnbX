# BNBx Suspicious Amount Agent

## Supported Chains

- BSC

## Alerts

- BNBx-LARGE-MINT

  - Fired when BNBx is minted in large amount (500 BNBx)
  - Severity is set to "High"
  - Type is set to "Info"
  - metadata: to, value

- BNBx-LARGE-UNSTAKE

  - Fired when User unstakes large amount of BNBx (500 BNBx)
  - Severity is set to "High"
  - Type is set to "Info"
  - metadata: account, amountInBnbX,

- BNBx-ER-DROP

  - Fired when Exchange Rate Drops
  - Severity is set to "Critical"
  - Type is set to "Exploit"
  - metadata: lastER, currentER

- BNBx-SUPPLY-MISMATCH

  - Fired when ER \* BNBX_SUPPLY != TOTAL_POOLED_BNB
  - Severity is set to "Critical"
  - Type is set to "Exploit"
  - metadata: currentER, totalPooledBnb, currentSupply

- BNBx-SUPPLY-CHANGE

  - Fired when BNBx Supply Changes by 10%
  - Severity is set to "High"
  - Type is set to "Suspicious"
  - metadata: lastSupply, currentSupply
