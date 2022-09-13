using BnbX as bnbX

methods{
    //harness methods
    getUserWithdrawalRequestLength(address) returns (uint256) envfree;
    getUserWithdrawalRequestBnbXAmt(address, uint256) returns (uint256) envfree;
    getNativeTokenBalance(address) returns (uint256) envfree;

    convertBnbToBnbX(uint256) returns (uint256) envfree;
    convertBnbXToBnb(uint256) returns (uint256) envfree;
    hasRole(bytes32, address) returns (bool) envfree;

    //variables
    BOT() returns (bytes32) envfree;

    // getters
    totalBnbXToBurn() returns (uint256) envfree;
    totalClaimableBnb() returns (uint256) envfree;
    getBnbXWithdrawLimit() returns (uint256) envfree;
    getTotalPooledBnb() returns (uint256) envfree;
    getUserWithdrawalRequests(address) returns ((uint256,uint256,uint256)[]) envfree;
    getUserRequestStatus(address, uint256) returns (bool, uint256) envfree;
    getContracts() returns (
            address _manager,
            address _bnbX,
            address _tokenHub,
            address _bcDepositWallet
        ) envfree;

    // bnbX.sol
    bnbX.totalSupply() returns (uint256) envfree;
    bnbX.balanceOf(address) returns (uint256) envfree;

    
    // ERC20Upgradable summarization
    transfer(address to, uint256 amount) returns (bool) => DISPATCHER(true);
}

rule userDepositsAndGetsCorrectAmountOfBnbX(address user, uint256 amount) {
    env e;
    require e.msg.sender == user;
    require e.msg.value == amount;

    uint256 bnbXAmount = convertBnbToBnbX(amount);
    uint256 userBnbXBalanceBefore = bnbX.balanceOf(user);

    deposit(e);

    uint256 userBnbXBalanceAfter = bnbX.balanceOf(user);

    assert userBnbXBalanceAfter == userBnbXBalanceBefore + bnbXAmount;
}

rule depositIncreasesTotalPooledBnb() {
    env e;

    uint256 pooledBnbBefore = getTotalPooledBnb();

    deposit(e);

    uint256 pooledBnbAfter = getTotalPooledBnb();

    assert pooledBnbAfter == pooledBnbBefore + e.msg.value;
}

rule totalSupplyIsCorrectAfterDeposit(address user, uint256 amount){
    env e;

    require e.msg.sender == user;
    require e.msg.value == amount;

    uint256 totalSupplyBefore = bnbX.totalSupply();

    require totalSupplyBefore + amount <= max_uint256;
    
    uint256 bnbXAmount = convertBnbToBnbX(amount);
    deposit(e);

    uint256 totalSupplyAfter = bnbX.totalSupply();

    assert amount != 0 => totalSupplyBefore + bnbXAmount == totalSupplyAfter;
}


rule totalSupplyDoesNotChangeAfterRequestWithdraw(uint256 unstakeBnbXAmount){
    env e;

    uint256 totalSupplyBefore = bnbX.totalSupply();

    requestWithdraw(e, unstakeBnbXAmount);

    uint256 totalSupplyAfter = bnbX.totalSupply();

    assert totalSupplyBefore == totalSupplyAfter;
}

rule totalSupplyDoesNotChangeAfterClaimWithdraw(uint256 idx){
    env e;

    uint256 totalSupplyBefore = bnbX.totalSupply();

    claimWithdraw(e, idx);

    uint256 totalSupplyAfter = bnbX.totalSupply();

    assert totalSupplyBefore == totalSupplyAfter;
}

rule erDoesNotChangeOnTransfer() {
    env e;
    uint256 oneEther = 10^18;
    uint256 erBefore = convertBnbXToBnb(oneEther);

    address otherUser; 
    uint256 amount;

    bnbX.transfer(e, otherUser, amount);

    uint256 erAfter = convertBnbXToBnb(oneEther);

    assert erBefore == erAfter;

}

// generic function `f` invoked with its specific `args`
rule userDoesNotChangeOtherUserBalance(method f, address otherUser){
    env e;
    calldataarg args;
    
    address manager;
    address _;
    manager, _, _, _ = getContracts();
    bytes32 BOT_ROLE = BOT();

    require !hasRole( BOT_ROLE, e.msg.sender);
    require e.msg.sender != manager;
    

    uint256 otherUserBnbXBalanceBefore = bnbX.balanceOf(otherUser);
    f(e,args);
    uint256 otherUserBnbXBalanceAfter = bnbX.balanceOf(otherUser);
    assert ((otherUser != e.msg.sender) => otherUserBnbXBalanceBefore == otherUserBnbXBalanceAfter);
}

rule bankRunSituation(){
    env e1;
    env e2;
    env e3;

    uint256 bnbxAmt1 = convertBnbToBnbX(e1.msg.value);
    deposit(e1);

    uint256 bnbxAmt2 = convertBnbToBnbX(e2.msg.value);
    deposit(e2);

    uint256 bnbxAmt3 = convertBnbToBnbX(e3.msg.value);
    deposit(e3);
    
    // All user unstakes
    // user1 unstakes
    requestWithdraw(e1, bnbxAmt1);

    uint256 userRequestLength1 = getUserWithdrawalRequestLength(e1.msg.sender);
    uint256 userRequestBnbXAmt1 = getUserWithdrawalRequestBnbXAmt(e1.msg.sender, 0);
    require userRequestLength1 == 1 && userRequestBnbXAmt1 == bnbxAmt1;

    bool isClaimable1;
    uint256 _amount1;
    isClaimable1, _amount1 = getUserRequestStatus(e1.msg.sender, 0);
    require isClaimable1 == true;

    uint256 user1BnbBalanceBefore = getNativeTokenBalance(e1.msg.sender);
    claimWithdraw(e1, 0);
    uint256 user1BnbBalanceAfter = getNativeTokenBalance(e1.msg.sender);

    assert (user1BnbBalanceAfter == user1BnbBalanceBefore + _amount1);

    // user2 unstakes
    requestWithdraw(e2, bnbxAmt2);

    uint256 userRequestLength2 = getUserWithdrawalRequestLength(e2.msg.sender);
    uint256 userRequestBnbXAmt2 = getUserWithdrawalRequestBnbXAmt(e2.msg.sender, 0);
    require userRequestLength2 == 1 && userRequestBnbXAmt2 == bnbxAmt2;

    bool isClaimable2;
    uint256 _amount2;
    isClaimable2, _amount2 = getUserRequestStatus(e2.msg.sender, 0);
    require isClaimable2 == true;

    uint256 user2BnbBalanceBefore = getNativeTokenBalance(e2.msg.sender);
    claimWithdraw(e2, 0);
    uint256 user2BnbBalanceAfter = getNativeTokenBalance(e2.msg.sender);

    assert (user2BnbBalanceAfter == user2BnbBalanceBefore + _amount2);
    
    // user3 unstakes
    requestWithdraw(e3, bnbxAmt3);

    uint256 userRequestLength3 = getUserWithdrawalRequestLength(e3.msg.sender);
    uint256 userRequestBnbXAmt3 = getUserWithdrawalRequestBnbXAmt(e3.msg.sender, 0);
    require userRequestLength3 == 1 && userRequestBnbXAmt3 == bnbxAmt3;

    bool isClaimable3;
    uint256 _amount3;
    isClaimable3, _amount3 = getUserRequestStatus(e3.msg.sender, 0);
    require isClaimable3 == true;

    uint256 user3BnbBalanceBefore = getNativeTokenBalance(e3.msg.sender);
    claimWithdraw(e3, 0);
    uint256 user3BnbBalanceAfter = getNativeTokenBalance(e3.msg.sender);

    assert (user3BnbBalanceAfter == user3BnbBalanceBefore + _amount3);

    assert (getTotalPooledBnb()==0 && totalClaimableBnb()==0) => (totalBnbXToBurn()==0 && getBnbXWithdrawLimit() == 0);
}