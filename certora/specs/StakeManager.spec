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

rule depositIncreasesTotalPooledBnb() {
    env e;

    uint256 pooledBnbBefore = getTotalPooledBnb();

    deposit(e);

    uint256 pooledBnbAfter = getTotalPooledBnb();

    assert pooledBnbAfter == pooledBnbBefore + e.msg.value;
}

// rule totalSupplyIsCorrectAfterDeposit(address user, uint256 amount){
//     env e;

//     require e.msg.sender == user;
//     require e.msg.value == amount;

//     uint256 totalSupplyBefore = BnbX.totalSupply();

//     require totalSupplyBefore + amount <= 500;
//     deposit(e);

//     uint256 totalSupplyAfter = BnbX.totalSupply();
//     uint256 userBnbXBalance = BnbX.balanceOf(user);

//     assert userBnbXBalance == amount;
//     assert amount != 0 => totalSupplyBefore < totalSupplyAfter;
// }