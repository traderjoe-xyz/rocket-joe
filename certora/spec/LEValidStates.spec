import "./LEPreset.spec"

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
    requireInvariant statesComplete();

    // requireInvariant alwaysInitialized()
    // requireInvariant factoryGetPairCorrelationCurrentVals(e)
    // requireInvariant al_issuer_allocation_zero()
    // requireInvariant al_balance_less_than_allocation(address user)
    // requireInvariant al_userAllocation_less_than_maxAllocation(address user)
    // requireInvariant initIssuerTimelockNonZero()
    // requireInvariant initUserTimelockSeven()
    // requireInvariant initAuctionStart(e)
    // requireInvariant initTimelocksCorrelation()
    // requireInvariant init_IncentivesCorrelation()
    // requireInvariant init_TokenBalanceCheck(e)
    // requireInvariant op_user_not_withdrawn_pair(address user)
    // requireInvariant op_user_not_withdrawn_incentives(address user)
    // requireInvariant opWavaxBalanceAndSumBalances()
    // requireInvariant opTokenBalanceCheck()
    // requireInvariant op_IncentivesCorrelation()
    // requireInvariant op_avax_alloc_zero()
    // requireInvariant op_lp_supply_zero()
    // requireInvariant opPairBalanceIsZero()
    // requireInvariant opPairAndTotalSupplyCorrelation()
    // requireInvariant cl_avax_alloc_sum_user_balances()
    // requireInvariant cl_avaxReservCheck()
    // requireInvariant cl_PhaseCheck(env e)
    // requireInvariant cl_AvaxCorrelation(env e)
    // requireInvariant cl_pair_bal_eq_lp_sum()
    // requireInvariant cl_token_bal_eq_res_token()
    // requireInvariant cl_incentivesCorrelation()
    // requireInvariant cl_nonzero_user_pair_bal(address user, env e)
    // requireInvariant cl_bal_this_zero()
    // requireInvariant pairAndGetPairCorrelation(env e)
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
    Factory.getPair(e, token(), WAVAX()) == Factory.getPair(e, WAVAX(), token())
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
// - `auctionStart` > block.timestamp
invariant initAuctionStart(env e)
    auctionStart() > e.block.timestamp
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
    open() => tokenReserve() + tokenIncentivesForUsers() + tokenAllocated() + tokenIncentiveIssuerRefund() == getTokenBalanceOfThis()  // issuer and avaxAllocation
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



// STATUS - verified with not verified invarinat below
// run without preserved block: 
// run with preserved block: https://vaas-stg.certora.com/output/3106/9d59b11fd419a4c1de61/?anonymousKey=bfa92a50ea74047c15fb9f6d72c4f83ab2d366c5
//  - avaxAllocated is Σ getUA[user].balance (avaxReserve() is added as a fix to violations in depost and withdraw)
invariant cl_avax_alloc_sum_user_balances()
    closed() => avaxAllocated() + avaxReserve() == sum_of_users_balances()
    { preserved with (env e2) { safeAssumptions(e2); } }


// violation in depositAVAX(): https://vaas-stg.certora.com/output/3106/556ff34c4400705cf2cc/?anonymousKey=32fb2e318b921c45daa6c7012c63363f0a6cf24e
// idk how to fix it except restrict phase
invariant cl_avaxReservCheck()
    closed() => avaxReserve() == 0
    { preserved with (env e2) { safeAssumptions(e2); } }


invariant cl_PhaseCheck(env e)
    closed() => currentPhase(e) == PhaseThree()
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - in progress 
// run without preserved block: 
// run with preserved block: 
invariant cl_AvaxCorrelation(env e)
    closed() => (getBalanceOfThis() == avaxReserve() && avaxReserve() == 0)
    { preserved with (env e2) { safeAssumptions(e2); } }


// STATUS - in progress
// run without preserved block: 
// run with preserved block: 
// - pair balance of this = sum of unwithdrawn lp tokens over all users (half to issuers, remainder to users)
// up to roundoff
invariant cl_pair_bal_eq_lp_sum()
    closed() => (getPairBalanceOfThis() == lpSupply() / 2 + unwithdrawn_users_lp_tokens)
    { preserved with (env e2) { safeAssumptions(e2); } }


//  - token balance of this = sum of unwithdrawn reserve tokens (as above)  // enough incentives to pay everyone 
invariant cl_token_bal_eq_res_token()
    closed() => getTokenBalanceOfThis() == tokenIncentivesBalance()
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


// STATUS - verified (with harness)
// -rule_sanity: https://vaas-stg.certora.com/output/3106/c3e711b31a414808a3b3/?anonymousKey=f66a6ec74c47d93a1b72a66ce79cdee30ab9b7ff
// pair and getPair() should return the same adderess
invariant pairAndGetPairCorrelation(env e)
    closed() => pair() == Factory.getPair(e, WAVAX(), token())
    { preserved with (env e2) { safeAssumptions(e2); } }


////////////////////////////////////////////
// STOPPED
////////////////////////////////////////////

// TODO: specifiation for stopped state

////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

// STATUS - verified
// this was listed as an invariant, but writing a fixed value property makes more sense as a parametric rule
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


// STATUS - verified (wirh phase require)
// run of clear rule: https://vaas-stg.certora.com/output/3106/9a14fbfc06f5370a3ff8/?anonymousKey=47be67415c25ce594ca9756c7f1345a2dc65b91b
// run with requires: https://vaas-stg.certora.com/output/3106/c67f41b614e18d7efea7/?anonymousKey=0b1b8ed56327b03298dec62bada231b20c8df0ff
// was listed as an invariant but makes more sense as a parametric rule
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


// STATUS - in progress (createPair has pair == 0 OR totalSupply == 0 - it's the issue)
// can require pair.totalSupply > 0; it should fix the issue
// run of clear rule: https://vaas-stg.certora.com/output/3106/6069ba941c41dddb93d0/?anonymousKey=ff0feaa921181f9619053106c79339e70e6c68a4
// run with requires: https://vaas-stg.certora.com/output/3106/a505898e420fa73c6f46/?anonymousKey=4e20fb5ac95682f53cfbe50ffc848f11c151a5b9
// TODO: maybe this doesn't make sense to check anymore
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

// STATUS - in progress (the same issue as above)
// run of clear rule: https://vaas-stg.certora.com/output/3106/3a0c7c688b06022747cf/?anonymousKey=b77728a94b1d226a2beec6070cf021b13673db34
// run with requires: https://vaas-stg.certora.com/output/3106/97f94a4070310e71fcc6/?anonymousKey=886fa365aa4a2a5f32009b54a816d1f5d1c8afe5
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
