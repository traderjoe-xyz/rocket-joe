////////////////////////////////////////////////////////////////////////////
//                      Methods                                           //
////////////////////////////////////////////////////////////////////////////

methods {
    // functions
    initialize(address, uint256, address, uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    // currentPhase() returns (Phase) // TODO
    depositAVAX()
    withdrawAVAX(uint256)
    createPair()
    withdrawLiquidity()
    withdrawIncentives()
    emergencyWithdraw()
    allowEmergencyWithdraw()
    skim()
    getPenalty() returns (uint256)
    getReserves() returns (uint256, uint256)
    getRJoeAmount(uint256) returns (uint256)
    pairBalance(address) returns (uint256)
    // _atPhase(Phase _phase)
    _safeTransferAVAX(address, uint256)

    // generated getters
    issuer() returns(address) envfree
    auctionStart() returns(uint256) envfree
    PHASE_ONE_DURATION() returns(uint256) envfree
    PHASE_ONE_NO_FEE_DURATION() returns(uint256) envfree
    PHASE_TWO_DURATION() returns(uint256) envfree
    tokenIncentivesPercent() returns(uint256) envfree
    floorPrice() returns(uint256) envfree
    userTimelock() returns(uint256) envfree
    issuerTimelock() returns(uint256) envfree
    maxWithdrawPenalty() returns(uint256) envfree
    fixedWithdrawPenalty() returns(uint256) envfree
    rJoePerAvax() returns(uint256) envfree
    initialized() returns(bool) envfree
    stopped() returns(bool) envfree
    maxAllocation() returns(uint256) envfree
}


// we will want a definition that determines the phase

////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////


// ALWAYS

invariant issuer_allocation_zero()
    false


// UNINITIALIZED
// make sure important variables are 0

// INITIALIZED
// make sure important variables are non-zero

// OPEN

// open implies pair is zero
invariant op_pair_zero()
    false

// open implies not stopped
invariant op_not_stopped()
    false

// open implies user has not withdrawn
invariant op_user_not_withdrawn_pair()
    false
//  - getUA[user].hasWithdrawnPair is false

// - WAVAX balance of this == Σ getUA[user].allocation
invariant op_sum_user_alloc()
    false

// - avaxAllocated is 0
invariant op_avax_alloc_zero()
    false

//  - tokenAllocated is 0
invariant op_token_alloc_zero()
    false

//  - lpSupply is 0
invariant op_lp_supply_zero()
    false

// - tokenReserve is token balance of this
invariant op_token_res_eq_this()
    false

// CLOSED

//  - pair is nonzero
invariant cl_nonzero_pair()
    false

//  - isStopped is false
invariant cl_not_stopped()
    false

//  - user hasWithdrawnPair <=> pair balance of user is nonzero [can be more specific]
invariant cl_nonzero_user_pair_bal()
    false

//  - avaxAllocated is Σ getUA[user].allocation
invariant cl_avax_alloc_sum_user_alloc()
    false

//  - WAVAX balance of this is 0
invariant cl_bal_this_zero()
    false

//  - pair balance of this = sum of unwithdrawn lp tokens over all users (half to issuers, remainder to users)
//  up to roundoff
invariant cl_pair_bal_eq_lp_sum()
    false

//  - token balance of this = sum of unwithdrawn reserve tokens (as above)
invariant cl_token_bal_eq_res_token()
    false



// STOPPED

////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

// this was listed as an invariant, but writing a fixed value property makes more sense as a parametric rule
//  - tokenReserve is fixed (probably nonzero)
rule op_token_res_fixed(method f) {

    assert false, "not yet implemented";
}

// was listed as an invariant but makes more sense as a parametric rule
//  - (getUA[user].allocation is constant)
rule cl_user_alloc_fixed(method f) {

    assert false, "not yet implemented";
}

//  - avaxAllocated, tokenAllocated, lpSupply, tokenReserve are unchanging

rule cl_avax_alloc_fixed(method f) {

    assert false, "not yet implemented";
}

rule cl_token_alloc_fixed(method f) {

    assert false, "not yet implemented";
}

rule cl_lp_supply_fixed(method f) {

    assert false, "not yet implemented";
}

rule cl_token_res_fixed(method f) {

    assert false, "not yet implemented";
}