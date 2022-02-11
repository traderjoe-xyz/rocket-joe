import "./LEPreset.spec"

use invariant oneStateOnly

// This function is here because:
// 1. I requireInvariants from this file
// 2. Preset spec will need import this spec
// 3. Cyclic dependencies are forbidden
function addressDiversity(env e) {
    require token() != currentContract;
    require token() != Weth;

    require Weth != currentContract;

    require e.msg.sender != currentContract;
    require e.msg.sender != Weth;
    require e.msg.sender != token();

    require pair() != token();
    require pair() != Weth;
    require pair() != currentContract;
    require pair() != e.msg.sender;

    require rJoe() != Weth;
    require rJoe() != token();
    require rJoe() != pair();
    require rJoe() != e.msg.sender;
    require rJoe() != currentContract;

    require factoryGetPairWT() != currentContract;
    require factoryGetPairWT() != Weth;
    require factoryGetPairWT() != token();
    require factoryGetPairWT() != e.msg.sender;
    require factoryGetPairWT() != pair();
    require factoryGetPairWT() != rJoe();

    require factoryGetPairTW() != currentContract;
    require factoryGetPairTW() != Weth;
    require factoryGetPairTW() != token();
    require factoryGetPairTW() != e.msg.sender;
    require factoryGetPairTW() != pair();
    require factoryGetPairTW() != rJoe();
}

function safeAssumptions(env e) {
    addressDiversity(e);

    // always true
    require e.msg.sender != 0;

    // We assume that there are no launch tokens in circulation before the
    // launch, and therefore there can be no supply of LP tokens.
    //
    // This assumption can be violated by the issuer.
    require open() => getPairTotalSupply() == 0;

    requireInvariant alwaysInitialized();
    requireInvariant oneStateOnly();

    requireInvariant factoryGetPairCorrelationCurrentVals(e);
    requireInvariant al_issuer_allocation_zero();
    requireInvariant pairAndGetPairCorrelation(e);
    requireInvariant al_balance_less_than_allocation(e.msg.sender);
    requireInvariant al_userAllocation_less_than_maxAllocation(e.msg.sender);

    requireInvariant initIssuerTimelockNonZero();
    requireInvariant initUserTimelockSeven();
    requireInvariant initTimelocksCorrelation();
    requireInvariant init_IncentivesCorrelation();
    requireInvariant init_TokenBalanceCheck(e);
    
    requireInvariant op_user_not_withdrawn_pair(e.msg.sender);
    requireInvariant op_user_not_withdrawn_incentives(e.msg.sender);
    requireInvariant opWavaxBalanceAndSumBalances();
    requireInvariant opTokenBalanceCheck();
    requireInvariant op_IncentivesCorrelation();
    requireInvariant op_avax_alloc_zero();
    requireInvariant op_lp_supply_zero();
    requireInvariant opPairBalanceIsZero();
    requireInvariant opPairAndTotalSupplyCorrelation();
    
    // requireInvariant cl_pairTotalZero();
    requireInvariant cl_avax_alloc_sum_user_balances();
    requireInvariant cl_avaxReservCheck();
    // requireInvariant cl_PhaseCheck(e);
    requireInvariant cl_AvaxCorrelation(e);
    // requireInvariant cl_pair_bal_eq_lp_sum();
    requireInvariant cl_token_bal_eq_res_token();
    requireInvariant cl_incentivesCorrelation();
    requireInvariant cl_nonzero_user_pair_bal(e.msg.sender, e);
    requireInvariant cl_bal_this_zero();
}

////////////////////////////////////////////
// HELPERS
////////////////////////////////////////////

invariant alwaysInitialized()
    auctionStart() != 0


// STATUS - verified (with harness)
// --rule_sanity failed instate: https://vaas-stg.certora.com/output/3106/2de5b9f58130ede9258d/?anonymousKey=1395a42b2a103b263f982faa8130a8b892f7a1b6
// getPair() should return the same results for both permutations (for current values in the contract)
invariant factoryGetPairCorrelationCurrentVals(env e)
    factoryGetPairWT() == factoryGetPairTW()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified (with harness)
// getPair() should return the same results for both permutations (for new values that can be assigned in initialize())
invariant factoryGetPairCorrelationNewVals(env e, address token)
    Factory.getPair(e, token, getNewWAVAX()) == Factory.getPair(e, getNewWAVAX(), token)
    { preserved with (env e2) { safeAssumptions(e2); } }


////////////////////////////////////////////
// ALWAYS
////////////////////////////////////////////


// STATUS - verified
// - getUI[issuer].allocation == 0
invariant al_issuer_allocation_zero()
    getUserAllocation(issuer()) == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// - getUI[user].balance <= getUI[user].allocation
invariant al_balance_less_than_allocation(address user)
    getUserBalance(user) <= getUserAllocation(user) 
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// - getUI[user].allocation <= maxAllocation
invariant al_userAllocation_less_than_maxAllocation(address user)
    getUserAllocation(user) <= maxAllocation()
    { preserved with (env e2) { safeAssumptions(e2); } }
    

// STATUS - verified
// - `issuerTimelock` >= 1
invariant initIssuerTimelockNonZero()
    issuerTimelock() >= 1
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// - `userTimelock` <= 7 days
invariant initUserTimelockSeven()
    userTimelock() <= sevenDays()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
//  - `issuerTimelock` > `userTimelock`
invariant initTimelocksCorrelation()
    issuerTimelock() > userTimelock()
    { preserved with (env e2) { safeAssumptions(e2); } }


////////////////////////////////////////////
// OPEN
////////////////////////////////////////////


// STATUS - verified
// run without preserved block: https://vaas-stg.certora.com/output/3106/2a01649b1de2a49974c2/?anonymousKey=20f7ddb28e1a811155951516d32632ba6eebfc64
// run with preserved block: https://vaas-stg.certora.com/output/3106/20910e32db29fbc8d4b1/?anonymousKey=f75d8e2d6edadb729f1cffd9539bdec780a01daf
// need to require pair() == 0 to avoid withdrawIncentives(), otherwise violation
// - `tokenIncentivesForUsers` + tokenIncentiveIssuerRefund == `tokenIncentivesBalance`
invariant init_IncentivesCorrelation()
    open() => tokenIncentivesForUsers() + tokenIncentiveIssuerRefund() == tokenIncentivesBalance()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - in progress
// run without preserved block: https://vaas-stg.certora.com/output/3106/6b7da28e5fc10d4ae456/?anonymousKey=5f13d972f6299db791c6331ef9a8a4907582157e
// run with preserved block: https://vaas-stg.certora.com/output/3106/ae0992b1cbbc194c21f4/?anonymousKey=53e564ea846a2718c43b6a03673fd13beb4efdf3
//  - `tokenReserve` + `tokenIncentivesForUsers` == `token.balanceOf(address(this))`
invariant init_TokenBalanceCheck(env e)
    open() => tokenReserve() + tokenIncentivesForUsers() == getTokenBalanceOfThis()  // issuer and avaxAllocation
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// open implies user has not withdrawn
invariant op_user_not_withdrawn_pair(address user)
    open() => !userHasWithdrawnPair(user)
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// open implies user has not withdrawn
invariant op_user_not_withdrawn_incentives(address user)
    open() => !userHasWithdrawnIncentives(user)
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
//  - `avaxReserve` == Σ getUI[user].balance
invariant opWavaxBalanceAndSumBalances()
   open() => avaxReserve() == sum_of_users_balances()
   { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// run without preserved block: https://vaas-stg.certora.com/output/3106/b7fbec7151f41c40801f/?anonymousKey=eb238d3cca7dbe799ad24ab08248ea0dcebb1882
// run with preserved block: https://vaas-stg.certora.com/output/3106/296af20cba3dab8cf070/?anonymousKey=ffd62d65271c84d02180da5c8d96e0f89022e740
// - token balance of this >= tokenReserve
invariant opTokenBalanceCheck()
    open() => tokenReserve() + tokenIncentivesForUsers() == getTokenBalanceOfThis()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
invariant op_IncentivesCorrelation()
    open() => tokenIncentivesForUsers() == tokenIncentivesBalance()
    { preserved with (env e2) { safeAssumptions(e2); } }
    

// STATUS - verified
// - avaxAllocated is 0
invariant op_avax_alloc_zero()
    open() => avaxAllocated() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
//  - lpSupply is 0
invariant op_lp_supply_zero()
    open() => lpSupply() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// - pair.balanceOf(address(this)) == 0
invariant opPairBalanceIsZero()
    open() => getPairBalanceOfThis() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - in progress
// run without preserved block: https://vaas-stg.certora.com/output/3106/d5fe06df0b27049e8297/?anonymousKey=a848ee0fcdc25a890868a18a606e03e8d8f45b9e
// run with preserved block: https://vaas-stg.certora.com/output/3106/95c86b642cc036d07683/?anonymousKey=e3f30a22095e53ef27881704f34c59a3f29d601a
// TotalSupply of non-existing pair should be 0 
invariant opPairAndTotalSupplyCorrelation()
    open() => getPairTotalSupply() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


////////////////////////////////////////////
// CLOSED
////////////////////////////////////////////


// STATUS - in progress
invariant cl_pairTotalZero()
    closed() => getPairTotalSupplyOfThis() != 0 && getPairTotalSupply() == getPairTotalSupplyOfThis()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
//  - avaxAllocated is Σ getUA[user].balance (avaxReserve() is added as a fix to violations in depost and withdraw)
invariant cl_avax_alloc_sum_user_balances()
    closed() => avaxAllocated() + avaxReserve() == sum_of_users_balances()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - in progress (fail on deposit)
// https://vaas-stg.certora.com/output/3106/9c2fe56024490f8cae96/?anonymousKey=5708f2a562e6a156609242b832db7159e155f557
invariant cl_avaxReservCheck()
    closed() => avaxReserve() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// invariant PhaseCheck(env e)
//     ( open() => notstate currentPhase(e) == PhaseOne() || currentPhase(e) == PhaseTwo() || currentPhase(e) == PhaseThree() ) 
//             && ( closed() => currentPhase(e) == PhaseThree() )
//             && ( isStopped() => currentPhase(e) == PhaseOne() || currentPhase(e) == PhaseTwo() || currentPhase(e) == PhaseThree() ) 
//     { preserved with (env e2) { require e.block.timestamp == e2.block.timestamp;
//                                 safeAssumptions(e2); } }


// STATUS - in progress 
// assume issue in createPair() because of dispatcher: https://vaas-stg.certora.com/output/3106/daf1e9e56688d547ca48/?anonymousKey=2ce96e28028d5b67b424820cbd4d79be88ab835d
// tool doesn't know what to do with WAVAX.deposit{value: avaxAllocated}();
invariant cl_AvaxCorrelation(env e)
    closed() => (getBalanceOfThis() == avaxReserve() && avaxReserve() == 0)
    { 
        preserved with (env e2) { 
            safeAssumptions(e2); 
            require e2.msg.value == e.msg.value;
            require e2.msg.value == avaxReserve();
        } 
    }


// STATUS - in progress
// wrong ghost: https://vaas-stg.certora.com/output/3106/b84a03505e212d3ae954/?anonymousKey=5f802070bac9c44703cf0255acadc27ea379edc4
// - pair balance of this = sum of unwithdrawn lp tokens over all users (half to issuers, remainder to users)
// up to roundoff
invariant cl_pair_bal_eq_lp_sum()
    closed() => (getPairBalanceOfThis() == lpSupply() / 2 + unwithdrawn_users_lp_tokens)
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - in progress
// need it to fix invariant below (withdrawIncentives()) - not sure
invariant cl_issuerIncentivesAndGetIncCorrelation(env e)
    closed() => getIncentives(e, issuer()) == tokenIncentiveIssuerRefund()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - in progress
//  - token balance of this = sum of unwithdrawn reserve tokens (as above)  // enough incentives to pay everyone 
// dispatcher works incorrectly for withdrawLiquidity()
// withdrawIncentives() - idk if tokenIncentiveIssuerRefund should be equal tokenReserve after create pair
// what happens with token reserv in withdrawIncentives(): https://vaas-stg.certora.com/output/3106/2f75f745232805801f15/?anonymousKey=68f2356c24e5fc9846c6b7100518a1efff79539e
// older: https://vaas-stg.certora.com/output/3106/d6418346bfd3d8d224da/?anonymousKey=d6fde4a0938978a9fe521ee48bb0c87cb198906e#cl_token_bal_eq_res_token_preservecreatePair()CallTrace
invariant cl_token_bal_eq_res_token()
    closed() => getTokenBalanceOfThis() == tokenIncentivesBalance() + tokenReserve() // tokenReserve beceause of if in createPair()
    { preserved with (env e2) { safeAssumptions(e2); } }










// STATUS - in progress
// run without preserved block: 
// run with preserved block: 
// - `tokenIncentivesBalance` <= `tokenIncentivesForUsers`
invariant cl_incentivesCorrelation()
    closed() => (tokenIncentivesBalance() <= tokenIncentivesForUsers())
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - in progress
// run without preserved block: 
// run with preserved block: 
//  - user hasWithdrawnPair <=> pair balance of user is nonzero [can be more specific]
invariant cl_nonzero_user_pair_bal(address user, env e)
    closed() => (!userHasWithdrawnPair(user) <=> getPairBalance(user) != 0)
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - in progress
// run without preserved block: https://vaas-stg.certora.com/output/3106/1f16ef95b837c83df4fa/?anonymousKey=e76a5b8eb2daac59672bb7c219e776d608a4df5d
// run with preserved block: 
//  - WAVAX balance of this is 0
invariant cl_bal_this_zero()
    closed() => getWAVAXbalanceOfThis() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - verified
// -rule_sanity: https://vaas-stg.certora.com/output/3106/c3e711b31a414808a3b3/?anonymousKey=f66a6ec74c47d93a1b72a66ce79cdee30ab9b7ff
// pair and getPair() should return the same adderess
invariant pairAndGetPairCorrelation(env e)
    closed() => pair() ==  factoryGetPairWT() // Factory.getPair(e, WAVAX(), token())
    { preserved with (env e2) { safeAssumptions(e2); } }


////////////////////////////////////////////
// STOPPED
////////////////////////////////////////////

// TODO: specifiation for stopped state

////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

// STATUS - verified
// sanity issue: https://vaas-stg.certora.com/output/3106/8dfcc21ca9829a14afa8/?anonymousKey=9b79dd816505bd3748f94db3d078cda47ca2aa97
//  - tokenReserve is fixed (probably nonzero)
rule op_token_res_fixed(method f, env e) {
    safeAssumptions(e);

    require open();

    uint256 tokenReserveBefore = tokenReserve();

    calldataarg args;
    f(e, args);

    require open();

    uint256 tokenReserveAfter = tokenReserve();

    assert tokenReserveBefore == tokenReserveAfter, "tokenReserve was changed";
}


// STATUS - verified 
// sanity issue: https://vaas-stg.certora.com/output/3106/62b0954854dd88df7d94/?anonymousKey=ac2a2de905088ece00c7ddda287849a5a04e18b3
//   - getUA[user].allocation is unchanging
rule cl_user_alloc_unchanging(address user, method f, env e) {
    safeAssumptions(e);

    uint256 userAllocationBefore = getUserAllocation(user);

    require closed();
    calldataarg args;
    f(e, args);
    require closed();

    uint256 userAllocationAfter = getUserAllocation(user);

    assert userAllocationBefore == userAllocationAfter, "tokenReserve was changed";
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  - avaxAllocated, tokenAllocated, lpSupply, tokenReserve are unchanging
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// STATUS - verified
// sanity issue: https://vaas-stg.certora.com/output/3106/3bcde5e8b416f2c08b4b/?anonymousKey=b18c5d9e314bf734d1467f5cc04589b9d56da53d
rule cl_avax_alloc_fixed(method f, env e) {
    safeAssumptions(e);

    uint256 wavaxAllocatedBefore = avaxAllocated();

    require closed();
    calldataarg args;
    f(e, args);
    require closed();

    uint256 wavaxAllocatedAfter = avaxAllocated();

    assert wavaxAllocatedBefore == wavaxAllocatedAfter, "not yet implemented";
}

// STATUS - verified
// sanity issue: https://vaas-stg.certora.com/output/3106/8fda00fd319420fa60d7/?anonymousKey=0e32aea6972068594deacd19b34178abbd7005d8
rule cl_lp_supply_fixed(method f, env e) {
    safeAssumptions(e);

    uint256 lpSupplyBefore = lpSupply();

    require closed();
    calldataarg args;
    f(e, args);
    require closed();

    uint256 lpSupplyAfter = lpSupply();

    assert lpSupplyBefore == lpSupplyAfter, "not yet implemented";
}
