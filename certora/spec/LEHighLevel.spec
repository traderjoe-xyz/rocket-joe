import "./LEVarTran.spec"

// STATUS - in progress (check correctness, how to write a ghost)
// - pair balance of this == pair balance of issuer + Σ pair balance of user  == pair.totalSupply
invariant hl_EqualityOfPairs()
    getPairBalanceOfThis() == getPairBalance(issuer()) + sumOfPairBalances()


// STATUS - in progress
// run without preserved block: https://vaas-stg.certora.com/output/3106/1f91c36ac4e4424e389f/?anonymousKey=c30c7ee9fd1cb8fe7198145cf50a5e0959f623e4
// run with preserved block: 
invariant hl_EqualityOfPairAndTotalSupply()
    getPairBalanceOfThis() == getPairTotalSupplyOfThis()


// STATUS - in progress
// run without preserved block: https://vaas-stg.certora.com/output/3106/23f2a4a600d0a020f0cb/?anonymousKey=d1d4fef9e201e201fd039a0dd0ddc1ea5306c9d7
// run with preserved block: https://vaas-stg.certora.com/output/3106/9a888396ade18f00c01a/?anonymousKey=a7cdb01cf4b007d42ee8c2eb885757bfeebef6e6
invariant hl_TotalSupplyEquality()
    getPairTotalSupply() == getPairTotalSupplyOfThis()
    {
        preserved with (env e2){
            requireInvariant factoryGetPairCorrelationCurrentVals(e2);
            // requireInvariant factoryGetPairCorrelationNewVals(e2);
            requireInvariant pairAndGetPairCorrelation(e2);
            require Weth != currentContract;
        }
    }


// STATUS - in progress (check correctness)
// run without preserved block: https://vaas-stg.certora.com/output/3106/97ef875729677fd13d3e/?anonymousKey=2de9f81c045b5e5905703a7e1858051c83398e3c
// run with preserved block: https://vaas-stg.certora.com/output/3106/fd13b3facc56fe203493/?anonymousKey=215dd5bd8dea94c48915359907e365dafbeee0c1
// - token balance of this == tokenReserve + tokenIncentivesBalance
// don't see if loop for withdrawLiquidity()
// strange call trace for emergencyWithdraw()
invariant hl_EqualityOfToken(env e) 
    getTokenBalanceOfThis() == tokenReserve() + tokenIncentivesBalance()
    {
        preserved with (env e2){
            require token() == SymbERC20A || token() == SymbERC20B;     // depositAVAX() and many more          // token != instead of ==
            require e2.msg.sender != currentContract;                   // withdrawIncentives()
            require e.msg.sender == e2.msg.sender;       
            // require e2.msg.sender == issuer();               
        }
    }


// STATUS - in progress
// run of clear rule: https://vaas-stg.certora.com/output/3106/f4bc7ac13d8eb2bd3a0a/?anonymousKey=8f7ad6b696892571f8fd47f715a541e782849805
// run with requires:
// - additivity of deposit: deposit(a); deposit(b) has same effect as deposit(a+b)
rule hl_depositAdditivity(env e, env e2){
    require e.msg.value > 0;
    require e.msg.value == 2 * e2.msg.value;
    require e.msg.sender != e2.msg.sender;

    uint256 userOneBalanceBefore = getUserBalance(e.msg.sender);
    depositAVAX(e);
    uint256 userOneBalanceAfter = getUserBalance(e.msg.sender);
    
    uint256 userTwoBalanceBefore = getUserBalance(e2.msg.sender);
    require userOneBalanceBefore == userTwoBalanceBefore;
    depositAVAX(e2);
    depositAVAX(e2);
    uint256 userTwoBalanceAfter = getUserBalance(e2.msg.sender);

    assert userOneBalanceAfter == userTwoBalanceAfter, "deposit is not additive";
}


// STATUS - verified
// - additivity of withdraw:  withdraw(a); withdraw(b) has same effect as withdraw(a+b)
rule hl_withdrawAdditivity(env e){
    uint256 single; uint256 doubleOne; uint256 doubleTwo;
    require single > 0 && doubleOne > 0 && doubleTwo > 0;
    require single == doubleOne + doubleTwo;

    uint256 userBalanceAtStart = getUserBalance(e.msg.sender);

    storage initialStorage = lastStorage;
    withdrawAVAX(e, single);

    uint256 userBalanceAfterSingle = getUserBalance(e.msg.sender);

    withdrawAVAX(e, doubleOne) at initialStorage;
    withdrawAVAX(e, doubleTwo);

    uint256 userBalanceAfterDouble = getUserBalance(e.msg.sender);

    assert userBalanceAfterSingle == userBalanceAfterDouble, "withdraw is not additive";
}


// STATUS - in progress
// values are set in a way that pairBalance() returns 0: https://vaas-stg.certora.com/output/3106/8d248960ef13f105b235/?anonymousKey=8a2c40d9e5369140c4fae50b8a9705cef9b5bde4
// in withdrawIncentives() pair and token are mixed up by dispatcher (instead of token, pair transfer is used) that's why pairBalance was increased
// why was token balance increased too?
// run: https://vaas-stg.certora.com/output/3106/c1f832414d46105ad050/?anonymousKey=76fee1c34e2a9c4f7192143d89e967335e2f73c5
// maybe avaxAllocated() should be set correctly
// run: https://vaas-stg.certora.com/output/3106/0f95076ff69d2b551578/?anonymousKey=212ef1e0e250849feac6ffb6421768c745899ace
// maybe incentives too
// - if I deposit more AVAX, I receive more LP and launch tokens

// define formula for depositin in order to get more
rule hl_moreDepositMoreGet(method f, env e, env e2){
    require e.msg.sender != e2.msg.sender;
    require e.msg.sender != issuer();
    require e2.msg.sender != issuer();
    require e.msg.sender != currentContract;
    require e2.msg.sender != currentContract;
    require lpSupply() >= avaxAllocated(); // assumption, need to double check
    require token() == SymbERC20A || token() == SymbERC20B;

    uint256 balanceOfuser1 = getUserBalance(e.msg.sender);
    uint256 balanceOfuser2 = getUserBalance(e2.msg.sender);
    require balanceOfuser2 > balanceOfuser1;
    require avaxAllocated() >= balanceOfuser2 + balanceOfuser1;

    uint256 pairOfuser1Before = getPairBalance(e.msg.sender);
    uint256 tokenOfuser1Before = getTokenBalance(e.msg.sender);

    uint256 pairOfuser2Before = getPairBalance(e2.msg.sender);
    uint256 tokenOfuser2Before = getTokenBalance(e2.msg.sender);

    require pairOfuser1Before == pairOfuser2Before;
    require tokenOfuser1Before == tokenOfuser2Before;

    withdrawLiquidity(e);
    withdrawIncentives(e);
    // check how much can I withdrawLiquidity or how much I withdrawn
    uint256 pairOfuser1After = getPairBalance(e.msg.sender);
    // check how much can I withdrawIncentives or how much I withdrawn
    uint256 tokenOfuser1After = getTokenBalance(e.msg.sender);

    withdrawLiquidity(e2);
    withdrawIncentives(e2);
    // check how much can I withdrawLiquidity or how much I withdrawn
    uint256 pairOfuser2After = getPairBalance(e2.msg.sender);
    // check how much can I withdrawIncentives or how much I withdrawn
    uint256 tokenOfuser2After = getTokenBalance(e2.msg.sender);

    //assert
    assert pairOfuser1After < pairOfuser2After && tokenOfuser1After < tokenOfuser2After, "more deposit doesn't guarantee more rewards";
}


// STATUS - in progress
// need to play with setup: https://vaas-stg.certora.com/output/3106/7dbf520e634a88f8f53d/?anonymousKey=f1f9b5601b6ba73425a4c3389ef0408e658ba972
// - if I withdraw AVAX later, I have a larger penalty
rule hl_withdrawLateMorePenalty(method f, env e, env e2){
    // define phase 1, the second half

    require auctionStart() < e.block.timestamp;
    require e.block.timestamp < e2.block.timestamp;
    require e.block.timestamp > oneDay() && e.block.timestamp < twoDays();
    require e2.block.timestamp < twoDays();

    require e.msg.sender == e2.msg.sender;
    require e.msg.sender != issuer();
    require e.msg.sender != currentContract;

    uint256 earlyPenalty = getPenalty(e);
    uint256 latePenalty = getPenalty(e2);

    assert earlyPenalty < latePenalty, "penalty isn't greater";
}


// STATUS - verified
// run of clear rule: 
// run with requires: 
// do I need to check for non-reverting? 
// - deposit and withdraw are two-sided inverses on the state (if successful)
rule hl_twoSideInverse(env e){
    uint256 amount;

    storage initialStorage = lastStorage;

    depositAVAX(e);
    withdrawAVAX(e, amount);
    uint256 balanceOfUser1 = getUserBalance(e.msg.sender);

    withdrawAVAX(e, amount) at initialStorage;
    depositAVAX(e);
    uint256 balanceOfUser2 = getUserBalance(e.msg.sender);

    assert balanceOfUser1 == balanceOfUser2, "balances are different";
}


// STATUS - verified. --rule_sanity fails on 2 methods: https://vaas-stg.certora.com/output/3106/aa1385e04d4954850309/?anonymousKey=12d1ecc17e5ad4ad9ca4dd2803136d0897ff898e 
// - no front-running for deposit: effect of deposit unchanged by an intervening operation by another user
rule hl_noDepositFrontRun(method f, env e, env e2){
    require e.msg.sender != e2.msg.sender;

    calldataarg args;

    storage initialStorage = lastStorage;

    uint256 userBalanceBefore = getUserBalance(e.msg.sender);
    depositAVAX(e);
    uint256 userBalanceAfter1 = getUserBalance(e.msg.sender);

    f(e2, args) at initialStorage;
    depositAVAX(e);

    uint256 userBalanceAfter2 = getUserBalance(e.msg.sender);

    assert userBalanceBefore + e.msg.value == userBalanceAfter1 && userBalanceBefore + e.msg.value == userBalanceAfter2, "frontrun on Deposit";
}


// STATUS - verified (assume the same as above)
// - no front-running for withdraw
rule hl_noWithdrawFrontRun(method f, env e, env e2){
    require e.msg.sender != e2.msg.sender;
    uint256 amount;

    calldataarg args;

    storage initialStorage = lastStorage;

    uint256 userBalanceBefore = getUserBalance(e.msg.sender);
    withdrawAVAX(e, amount);
    uint256 userBalanceAfter1 = getUserBalance(e.msg.sender);

    f(e2, args) at initialStorage;
    withdrawAVAX(e, amount);

    uint256 userBalanceAfter2 = getUserBalance(e.msg.sender);

    assert userBalanceBefore - amount == userBalanceAfter1 && userBalanceBefore - amount == userBalanceAfter2, "frontrun on Withdraw";
}


// STATUS - in progress. 
// Need phases. run: https://vaas-stg.certora.com/output/3106/b5504d1e06207a552948/?anonymousKey=465bcaf38ba6e5b1d88a97b655413542c853d014
// - no front-running for withdrawLiquidity
rule hl_noWithdrawLiquidityFrontRun(method f, env e, env e2){
    require e.msg.sender != e2.msg.sender;
    require e.msg.sender != currentContract;
    require e2.msg.sender != currentContract;

    calldataarg args;

    storage initialStorage = lastStorage;

    uint256 userBalanceBefore = getPairBalance(e.msg.sender);
    uint256 whatShouldGet1 = pairBalance(e, e.msg.sender);
    withdrawLiquidity(e);
    uint256 userBalanceAfter1 = getPairBalance(e.msg.sender);

    f(e2, args) at initialStorage;
    uint256 whatShouldGet2 = pairBalance(e, e.msg.sender);
    withdrawLiquidity(e);
    uint256 userBalanceAfter2 = getPairBalance(e.msg.sender);

    assert whatShouldGet1 == whatShouldGet2, "should get differs";
    assert userBalanceBefore + whatShouldGet1 == userBalanceAfter1 && userBalanceBefore + whatShouldGet2 == userBalanceAfter2, "frontrun on WithdrawLiquidity";
}


// - createPair can be called at least once (DoS check)
// no front running for create pair
rule hl_createPairAtLeastOnce(env e){
    require !stopped();

    // storage

    createPair(e);

    // storage


    assert !lastReverted, "createPair DoS";
}