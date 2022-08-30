# BNBx Suspicious Amount Agent

## Description

This agent alerts when

- BNBx is minted in large amount
- User unstakes large amount of BNBx

## Supported Chains

- BSC

## Alerts

- BNBx-1

  - Fired when BNBx is minted in large amount (500 BNBx)
  - Severity is set to "High"
  - Type is set to "Suspicious"
  - metadata: to, value

- BNBx-2
  - Fired when User unstakes large amount of BNBx (500 BNBx)
  - Severity is set to "High"
  - Type is set to "Suspicious"
  - metadata: account, amountInBnbX,
