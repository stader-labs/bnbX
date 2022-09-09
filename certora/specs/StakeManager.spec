using BnbX as BnbX

methods{
    convertBnbToBnbX(uint256) returns (uint256) envfree;
    convertBnbXToBnb(uint256) returns (uint256) envfree;

    // getters
    getTotalPooledBnb() returns (uint256) envfree;


    // BnbX.sol
    BnbX.totalSupply() returns (uint256) envfree
    BnbX.balanceOf(address) returns (uint256) envfree

    
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
