using BnbX as BnbX

methods{
    convertBnbToBnbX(uint256) returns (uint256) envfree;
    convertBnbXToBnb(uint256) returns (uint256) envfree;
    hasRole(bytes32, address) returns (bool) envfree;

    //variables
    BOT() returns (bytes32) envfree;

    // getters
    getTotalPooledBnb() returns (uint256) envfree;
    getContracts() returns (
            address _manager,
            address _bnbX,
            address _tokenHub,
            address _bcDepositWallet
        ) envfree;

    // BnbX.sol
    BnbX.totalSupply() returns (uint256) envfree;
    BnbX.balanceOf(address) returns (uint256) envfree;

    
    // ERC20Upgradable summarization
    transfer(address to, uint256 amount) returns (bool) => DISPATCHER(true);
}

rule userDepositsAndGetsCorrectAmountOfBnbX(address user, uint256 amount) {
    env e;
    require e.msg.sender == user;
    require e.msg.value == amount;

    uint256 bnbXAmount = convertBnbToBnbX(amount);
    uint256 userBnbXBalanceBefore = BnbX.balanceOf(user);

    deposit(e);

    uint256 userBnbXBalanceAfter = BnbX.balanceOf(user);

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

    uint256 totalSupplyBefore = BnbX.totalSupply();

    require totalSupplyBefore + amount <= max_uint256;
    
    uint256 bnbXAmount = convertBnbToBnbX(amount);
    deposit(e);

    uint256 totalSupplyAfter = BnbX.totalSupply();

    assert amount != 0 => totalSupplyBefore + bnbXAmount == totalSupplyAfter;
}


rule totalSupplyDoesNotChangeAfterRequestWithdraw(uint256 unstakeBnbXAmount){
    env e;

    uint256 totalSupplyBefore = BnbX.totalSupply();

    requestWithdraw(e, unstakeBnbXAmount);

    uint256 totalSupplyAfter = BnbX.totalSupply();

    assert totalSupplyBefore == totalSupplyAfter;
}

rule totalSupplyDoesNotChangeAfterClaimWithdraw(uint256 idx){
    env e;

    uint256 totalSupplyBefore = BnbX.totalSupply();

    claimWithdraw(e, idx);

    uint256 totalSupplyAfter = BnbX.totalSupply();

    assert totalSupplyBefore == totalSupplyAfter;
}

rule erDoesNotChangeOnTransfer() {
    env e;
    uint256 oneEther = 10^18;
    uint256 erBefore = convertBnbXToBnb(oneEther);

    address otherUser; 
    uint256 amount;

    BnbX.transfer(e, otherUser, amount);

    uint256 erAfter = convertBnbXToBnb(oneEther);

    assert erBefore == erAfter;

}

rule userDoesNotChangeOtherUserBalance(method f, address otherUser){
    env e;
    calldataarg args;
    
    address manager;
    address _;
    manager, _, _, _ = getContracts();
    bytes32 BOT_ROLE = BOT();

    require !hasRole( BOT_ROLE, e.msg.sender);
    require e.msg.sender != manager;
    

    uint256 otherUserBnbXBalanceBefore = BnbX.balanceOf(otherUser);
    f(e,args);
    uint256 otherUserBnbXBalanceAfter = BnbX.balanceOf(otherUser);
    assert ((otherUser != e.msg.sender) => otherUserBnbXBalanceBefore == otherUserBnbXBalanceAfter);
}

