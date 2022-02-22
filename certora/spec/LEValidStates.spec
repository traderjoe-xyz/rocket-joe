import "./LEPreset.spec"

use invariant oneStateOnly

// This function is here because:
// 1. I requireInvariants from this file
// 2. Preset spec will need import this spec
// 3. Cyclic dependencies are forbidden
function addressDiversity(env e) {
    require token() != currentContract;
    require token() != Weth;
    require token() != JP;
    require token() != RJT;

    require Weth != currentContract;

    require e.msg.sender != currentContract;
    require e.msg.sender != Weth;
    require e.msg.sender != token();
    require e.msg.sender != getPenaltyCollector();

    require pair() != token();
    require pair() != Weth;
    require pair() != currentContract;
    require pair() != e.msg.sender;
    require pair() != RJT;

    require rJoe() != Weth;
    require rJoe() != token();
    require rJoe() != pair();
    require rJoe() != e.msg.sender;
    require rJoe() != currentContract;
}

function safeAssumptions(env e) {
    addressDiversity(e);
    require e.msg.sender != 0;

    requireInvariant alwaysInitialized();
    requireInvariant oneStateOnly();
    requireInvariant factoryGetPairCorrelationCurrentVals(e);

    requireInvariant al_issuerAllocationZero();
    requireInvariant al_balanceLessThanAllocation(e.msg.sender);
    requireInvariant al_userAllocationLessThanMaxAllocation(e.msg.sender);
    requireInvariant al_issuerTimelockNonZero();
    requireInvariant al_userTimelockSeven();
    requireInvariant al_timelocksCorrelation();
    
    requireInvariant op_incentivesCorrelation();  
    requireInvariant op_userNotWithdrawnPair(e.msg.sender);
    requireInvariant op_userNotWithdrawnIncentives(e.msg.sender);
    requireInvariant op_wavaxBalanceAndSumBalances();
    requireInvariant op_avaxAllocZero();
    requireInvariant op_lpSupplyZero();
    requireInvariant op_PairBalanceIsZero();
    requireInvariant op_AvaxCorrelation();
    requireInvariant op_PairAndTotalSupplyCorrelation();
    requireInvariant op_tokenCorrelation();
    
    requireInvariant cl_avaxAllocSumUserBalances();
    requireInvariant cl_avaxReservCheck();
    requireInvariant cl_incentivesCorrelation();
    requireInvariant cl_pairAndGetPairCorrelation();

    requireInvariant os_tokenCorrelation();
    requireInvariant os_avaxAllocSumUserBalances();
}

////////////////////////////////////////////
// HELPERS
////////////////////////////////////////////

invariant alwaysInitialized()
    auctionStart() != 0


// STATUS - verified (with harness)
// getPair() should return the same results for both permutations
invariant factoryGetPairCorrelationCurrentVals(env e)
    factoryGetPairWT() == factoryGetPairTW()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// pair and getPair() should return the same adderess
invariant cl_pairAndGetPairCorrelation()
    closed() => pair() == factoryGetPairWT()
    { preserved with (env e2) { safeAssumptions(e2); } }



////////////////////////////////////////////
// ALWAYS
////////////////////////////////////////////



// STATUS - verified
// issuer's allocation is always 0
invariant al_issuerAllocationZero()
    getUserAllocation(issuer()) == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// user's balance cannot be greater than their allocation
invariant al_balanceLessThanAllocation(address user)
    getUserBalance(user) <= getUserAllocation(user) 
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// user's allocation cannot exceed `maxAllocation`.
invariant al_userAllocationLessThanMaxAllocation(address user)
    getUserAllocation(user) <= maxAllocation()
    { preserved with (env e2) { safeAssumptions(e2); } }
    

// STATUS - verified
// - `issuerTimelock` cannot be 0.
invariant al_issuerTimelockNonZero()
    issuerTimelock() >= 1
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// - `userTimelock` cannot exceed seven days.
invariant al_userTimelockSeven()
    userTimelock() <= sevenDays()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
//  - `issuerTimelock` is greater than `userTimelock`.
invariant al_timelocksCorrelation()
    issuerTimelock() > userTimelock()
    { preserved with (env e2) { safeAssumptions(e2); } }



////////////////////////////////////////////
// OPEN
////////////////////////////////////////////



// STATUS - verified
// incentives corrrelation: `tokenIncentivesForUsers` + tokenIncentiveIssuerRefund == `tokenIncentivesBalance`
invariant op_incentivesCorrelation()
    open() => tokenIncentivesForUsers() + tokenIncentiveIssuerRefund() == tokenIncentivesBalance()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// user cannot have flag `hasWithdrawnPair` set to true
invariant op_userNotWithdrawnPair(address user)
    open() => !userHasWithdrawnPair(user)
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// user cannot have flag `hasWithdrawnIncentives` set to true
invariant op_userNotWithdrawnIncentives(address user)
    open() => !userHasWithdrawnIncentives(user)
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// `avaxReserve` is equal to the sum of all users balances: `avaxReserve` == Σ getUI[user].balance
invariant op_wavaxBalanceAndSumBalances()
   open() => avaxReserve() == sum_of_users_balances()
   { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// `avaxAllocated` can be only 0
invariant op_avaxAllocZero()
    open() => avaxAllocated() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// `lpSupply` can be only 0
invariant op_lpSupplyZero()
    open() => lpSupply() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// pair.balanceOf(address(this)) can be only 0
invariant op_PairBalanceIsZero()
    open() => getPairBalanceOfThis() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified   
// TotalSupply of non-existing pair should be 0 
invariant op_PairAndTotalSupplyCorrelation()
    open() => getPairTotalSupplyOfThis() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// `address(this).balance` is equal to the `avaxReserve`
invariant op_AvaxCorrelation()
    open() => (getBalanceOfThis() == avaxReserve())
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// token.balanceOf(currentContract) >= tokenReserve + tokenIncentivesBalance
invariant op_tokenCorrelation()
    open() => getTokenBalanceOfThis() >= tokenReserve() + tokenIncentivesBalance()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// `tokenReserve` remains unchanged in open state.
rule op_tokenResFixed(method f, env e) {
    safeAssumptions(e);

    require open();

    uint256 tokenReserveBefore = tokenReserve();

    calldataarg args;
    f(e, args);

    require open();

    uint256 tokenReserveAfter = tokenReserve();

    assert tokenReserveBefore == tokenReserveAfter, "tokenReserve was changed";
}



////////////////////////////////////////////
// CLOSED
////////////////////////////////////////////



// STATUS - verified
// `avaxAllocated` is equal to the sum of all users balances: avaxAllocated is Σ getUA[user].balance
invariant cl_avaxAllocSumUserBalances()
    closed() => avaxAllocated() == sum_of_users_balances()
    { 
        preserved with (env e2) { 
            require currentPhase(e2) == PhaseThree();
            safeAssumptions(e2); 
        } 
    }


// STATUS - verified
// `avaxReserve` has to be 0
invariant cl_avaxReservCheck()
    closed() => avaxReserve() == 0
    { 
        preserved with (env e2) { 
            require currentPhase(e2) == PhaseThree();
            safeAssumptions(e2); 
        } 
    }


// STATUS - verified
// - `tokenIncentivesBalance` less than the sum of `tokenIncentivesForUsers` and tokenIncentiveIssuerRefund()
invariant cl_incentivesCorrelation()
    closed() => (tokenIncentivesBalance() <= tokenIncentivesForUsers() + tokenIncentiveIssuerRefund())
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// `getUA[user].allocation` remains unchanged
rule cl_userAllocUnchanging(address user, method f, env e) {
    safeAssumptions(e);
    require currentPhase(e) == PhaseThree();

    uint256 userAllocationBefore = getUserAllocation(user);

    require closed();
    calldataarg args;
    f(e, args);
    require closed();

    uint256 userAllocationAfter = getUserAllocation(user);

    assert userAllocationBefore == userAllocationAfter, "userAllocation was changed";
}


// STATUS - verified
// `avaxAllocated` remains unchanged 
rule cl_avaxAllocUnchanging(method f, env e) {
    safeAssumptions(e);

    uint256 avaxAllocatedBefore = avaxAllocated();

    require closed();
    calldataarg args;
    f(e, args);
    require closed();

    uint256 avaxAllocatedAfter = avaxAllocated();

    assert avaxAllocatedBefore == avaxAllocatedAfter, "avaxAllocated was changed";
}

// STATUS - verified
// `getUserInfo[user].balance` remains unchanged 
rule cl_userBalanceFixed(method f, env e, address user) {
    safeAssumptions(e);
    require currentPhase(e) == PhaseThree();

    uint256 balanceBefore = getUserBalance(user);

    require closed();
    calldataarg args;
    f(e, args);
    require closed();

    uint256 balanceAfter = getUserBalance(user);

    assert balanceBefore == balanceAfter, "userBalance was changed";
}


// STATUS - verified
// `lpSupply` remains unchanged
rule cl_lpSupplyFixed(method f, env e) {
    safeAssumptions(e);

    uint256 lpSupplyBefore = lpSupply();

    require closed();
    calldataarg args;
    f(e, args);
    require closed();

    uint256 lpSupplyAfter = lpSupply();

    assert lpSupplyBefore == lpSupplyAfter, "lpSupply was changed";
}



////////////////////////////////////////////
// STOPPED
////////////////////////////////////////////

// pair() == 0


// STATUS - verified
// token.balanceOf(currentContract) >= tokenReserve + tokenIncentivesBalance
invariant os_tokenCorrelation()
    openStopped() => getTokenBalanceOfThis() >= tokenReserve() + tokenIncentivesBalance()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// avaxReserve() == sum_of_users_balances()
invariant os_avaxAllocSumUserBalances()
    openStopped() => avaxReserve() == sum_of_users_balances()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// avaxReserve cannot increase
rule os_avaxReserveDecrease(method f, env e) {
    safeAssumptions(e);

    uint256 avaxBefore = avaxReserve();

    require openStopped();
    calldataarg args;
    f(e, args);
    require openStopped();

    uint256 avaxAfter = avaxReserve();

    assert avaxBefore >= avaxAfter, "avaxReserve is increasing";
}


// STATUS - verified
// user.balance cannot increase
rule os_userBalanceNonIncreasing(method f, env e) {
    safeAssumptions(e);

    uint256 balanceBefore = getUserBalance(e.msg.sender);

    require openStopped();
    calldataarg args;
    f(e, args);
    require openStopped();

    uint256 balanceAfter = getUserBalance(e.msg.sender);

    assert balanceBefore >= balanceAfter, "user balance is increasing";
}


// pair() != 0


// STATUS - verified
// `lpSupply` remains unchanged in closed state
rule cs_lpSupplyFixed(method f, env e) {
    safeAssumptions(e);

    uint256 lpSupplyBefore = lpSupply();

    require closedStopped();
    calldataarg args;
    f(e, args);
    require closedStopped();

    uint256 lpSupplyAfter = lpSupply();

    assert lpSupplyBefore == lpSupplyAfter, "lpSupply is different";
}


// STATUS - verified
// `user.balance` remains unchanged in closed state
rule cs_userBalanceFixed(method f, env e) {
    safeAssumptions(e);

    uint256 balanceBefore = getUserBalance(e.msg.sender);

    require closedStopped();
    calldataarg args;
    f(e, args);
    require closedStopped();

    uint256 balanceAfter = getUserBalance(e.msg.sender);

    assert balanceBefore == balanceAfter, "user balance is different";
}


// STATUS - verified
// `avaxAllocated` remains unchanged in closed state
rule cs_avaxAllocatedFixed(method f, env e) {
    safeAssumptions(e);

    uint256 avaxBefore = avaxAllocated();

    require closedStopped();
    calldataarg args;
    f(e, args);
    require closedStopped();

    uint256 avaxAfter = avaxAllocated();

    assert avaxBefore == avaxAfter, "avaxAllocated is different";
}
















// STATUS - in progress
// probably bug in a tool wavax balance is unchanged and no correlation in DummyWeth.balanceOf and DummyWeth.transfer(): 
// https://vaas-stg.certora.com/output/3106/b063b2a6bb598396a84e/?anonymousKey=358463f1e17d105b2ef89e4abdb765981f6bf4dd
rule cl_balThisZero(address user, method f, env e) {
    safeAssumptions(e);
    require currentPhase(e) == PhaseThree();

    uint256 wavaxBalanceBefore = getWAVAXbalanceOfThis();

    require open();
    calldataarg args;
    f(e, args);
    require closed();

    uint256 wavaxBalanceAfter = getWAVAXbalanceOfThis();

    assert wavaxBalanceBefore == wavaxBalanceAfter + avaxAllocated(), "tokenReserve was changed";   // maybe avaxReserve
}


// STATUS - in progress
// strange call trace of withdrawLiquidity() (especially prestate): https://vaas-stg.certora.com/output/3106/b4f5dd9d88ce430a69ae/?anonymous Key=05ee608c07c21797f435de179567f8376d11d98f
// - pair balance of this = sum of unwithdrawn lp tokens over all users (half to issuers, remainder to users)
// up to roundoff
invariant cl_pair_bal_eq_lp_sum()
    closed() => (getPairBalanceOfThis() == lpSupply() / 2 + unwithdrawn_users_lp_tokens)
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - in progress    
// createPair() - doesn't update getBalanceOfThis()
// https://vaas-stg.certora.com/output/3106/cb86218f80bf94009eab/?anonymousKey=95556169903be4867c1194617f38d4106b2eac62
invariant cl_AvaxCorrelation()
    closed() => (getBalanceOfThis() == avaxReserve() && avaxReserve() == 0)
    { 
        preserved with (env e2) { 
            require currentPhase(e2) == PhaseThree();
            safeAssumptions(e2); 
        } 
    }



/* 
sh certora/scripts/verifyLEValidStates.sh alwaysInitialized
sh certora/scripts/verifyLEValidStates.sh factoryGetPairCorrelationCurrentVals
sh certora/scripts/verifyLEValidStates.sh cl_pairAndGetPairCorrelation
sh certora/scripts/verifyLEValidStates.sh al_issuerAllocationZero
sh certora/scripts/verifyLEValidStates.sh al_balanceLessThanAllocation
sh certora/scripts/verifyLEValidStates.sh al_userAllocationLessThanMaxAllocation
sh certora/scripts/verifyLEValidStates.sh al_issuerTimelockNonZero
sh certora/scripts/verifyLEValidStates.sh al_userTimelockSeven
sh certora/scripts/verifyLEValidStates.sh al_timelocksCorrelation
sh certora/scripts/verifyLEValidStates.sh op_incentivesCorrelation
sh certora/scripts/verifyLEValidStates.sh op_userNotWithdrawnPair
sh certora/scripts/verifyLEValidStates.sh op_userNotWithdrawnIncentives
sh certora/scripts/verifyLEValidStates.sh op_wavaxBalanceAndSumBalances
sh certora/scripts/verifyLEValidStates.sh op_avaxAllocZero
sh certora/scripts/verifyLEValidStates.sh op_lpSupplyZero
sh certora/scripts/verifyLEValidStates.sh op_PairBalanceIsZero
sh certora/scripts/verifyLEValidStates.sh op_PairAndTotalSupplyCorrelation
sh certora/scripts/verifyLEValidStates.sh op_AvaxCorrelation
sh certora/scripts/verifyLEValidStates.sh op_tokenCorrelation
sh certora/scripts/verifyLEValidStates.sh op_tokenResFixed
sh certora/scripts/verifyLEValidStates.sh cl_avaxAllocSumUserBalances
sh certora/scripts/verifyLEValidStates.sh cl_avaxReservCheck
sh certora/scripts/verifyLEValidStates.sh cl_incentivesCorrelation
sh certora/scripts/verifyLEValidStates.sh cl_userAllocUnchanging
sh certora/scripts/verifyLEValidStates.sh cl_avaxAllocUnchanging
sh certora/scripts/verifyLEValidStates.sh cl_userBalanceFixed 
sh certora/scripts/verifyLEValidStates.sh cl_lpSupplyFixed
sh certora/scripts/verifyLEValidStates.sh os_tokenCorrelation
sh certora/scripts/verifyLEValidStates.sh os_avaxAllocSumUserBalances
sh certora/scripts/verifyLEValidStates.sh os_avaxReserveDecrease
sh certora/scripts/verifyLEValidStates.sh os_userBalanceNonIncreasing
sh certora/scripts/verifyLEValidStates.sh cs_lpSupplyFixed
sh certora/scripts/verifyLEValidStates.sh cs_userBalanceFixed
sh certora/scripts/verifyLEValidStates.sh cs_avaxAllocatedFixed
