# Integration guide

Liquid staking is achieved through `StakeManager` contract and the yield-bearing ERC-20 token `BnbX` is given to the user.

## 1. Stake BNB

Send BNB and receive liquid staking BnbX token.

```SOLIDITY
IStakeManager stakeManager = IStakeManager(STAKE_MANAGER_ADDRESS);
IStakeManager.deposit{value: msg.value}();
uint256 amountInBnbX = IBnbX(BNBX_ADDRESS).balanceOf(msg.sender);

emit StakeEvent(msg.sender, msg.value, amountInBnbX);
```

## 2. Unstake BNB

Send BnbX and create a withdrawal request.  
_BnbX approval should be given._

```SOLIDITY
require(
    IBnbX(BNBX_ADDRESS).approve(STAKE_MANAGER_ADDRESS, amount),
    "Not approved"
);
IStakeManager stakeManager = IStakeManager(STAKE_MANAGER_ADDRESS);
IStakeManager.requestWithdraw(amount);

emit UnstakeEvent(msg.sender, amount);
```

## 3. Claim BNB

After 7-15 days, BNB can be withdrawn.

```SOLIDITY
IStakeManager stakeManager = IStakeManager(STAKE_MANAGER_ADDRESS);
(bool isClaimable, uint256 amount) = getUserRequestStatus(
    msg.sender,
    _idx
);
require(isClaimable, "Not ready yet");

IStakeManager.claimWithdraw(_idx);
uint256 amount = address(msg.sender).balance;

emit ClaimEvent(msg.sender, amount);
```

## Full example:

```SOLIDITY
pragma solidity ^0.8.0;

import "IBnbX.sol";
import "IStakeManager.sol";

contract Example {
    event StakeEvent(
        address indexed _address,
        uint256 amountInBnb,
        uint256 amountInBnbX
    );
    event UnstakeEvent(address indexed _address, uint256 amountInBnbX);
    event ClaimEvent(address indexed _address, uint256 amountInBnb);

    address private STAKE_MANAGER_ADDRESS =
        "0x7276241a669489E4BBB76f63d2A43Bfe63080F2"; //mainnet address
    address private BNBX_ADDRESS = "0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275"; //mainnet address

    function stake() external payable {
        IStakeManager stakeManager = IStakeManager(STAKE_MANAGER_ADDRESS);
        IStakeManager.deposit{value: msg.value}();
        uint256 amountInBnbX = IBnbX(BNBX_ADDRESS).balanceOf(msg.sender);

        emit StakeEvent(msg.sender, msg.value, amountInBnbX);
    }

    function unstake(uint256 _amount) external {
        require(
            IBnbX(BNBX_ADDRESS).approve(STAKE_MANAGER_ADDRESS, _amount),
            "Not approved"
        );
        IStakeManager stakeManager = IStakeManager(STAKE_MANAGER_ADDRESS);
        IStakeManager.requestWithdraw(_amount);

        emit UnstakeEvent(msg.sender, _amount);
    }

    function claim(uint256 _idx) external {
        IStakeManager stakeManager = IStakeManager(STAKE_MANAGER_ADDRESS);
        (bool isClaimable, uint256 amount) = getUserRequestStatus(
            msg.sender,
            _idx
        );
        require(isClaimable, "Not ready yet");

        IStakeManager.claimWithdraw(_idx);
        uint256 amount = address(msg.sender).balance;

        emit ClaimEvent(msg.sender, amount);
    }
}

```
