using BnbX as BnbX

methods{
    BnbX.totalSupply() returns (uint256) envfree
}

rule depositShouldIncreaseBnbXTotalSupply(address user, uint256 amount){
    env e;

    require e.msg.sender == user;
    require e.msg.value == amount;

    uint256 totalSupplyBefore = BnbX.totalSupply();

    deposit(e);

    uint256 totalSupplyAfter = BnbX.totalSupply();

    assert totalSupplyBefore < totalSupplyAfter;
}