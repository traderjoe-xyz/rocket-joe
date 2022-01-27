////////////////////////////////////////////////////////////////////////////
//                      Methods                                           //
////////////////////////////////////////////////////////////////////////////

methods {
    // generated getters 
    lastRewardTimestamp() returns(uint256) envfree
    accRJoePerShare() returns(uint256) envfree
    PRECISION() returns(uint256) envfree
    rJoePerSec() returns(uint256) envfree
    // mapping(address => UserInfo) public userInfo;
    // Initialize(IERC20Upgradeable _joe, RocketJoeToken _rJoe, uint256 _rJoePerSec)
    
    // internal functions
    pendingRJoe(address) returns (uint256)
    deposit(uint256)
    withdraw(uint256)
    emergencyWithdraw()
    updateEmissionRate(uint256)
    _safeRJoeTransfer(address, uint256)

    // harness functions
    userJoe(address) returns(uint256) envfree
    userRewardDebt(address) returns(uint256) envfree
}

rule sanity(method f) {
    env e; calldataarg args;
    f(e, args);
    assert false;
}

////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////

// rJoe.totalSupply is sum of rJoe balances
invariant User_RJ_balance_sums_supply()
    false

//rJoe.balanceOf(RJStaking) ≥ Σ pendingRewards over all users
invariant staking_RJ_balance_eq_pending_rewards()
    false

//joe.balanceOf(RJStaking)  ≥ Σ userInfo[user].amount
invariant staking_joe_bal_sums_user_balance()
    false
 
////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

//userInfo[user].amount only changed by user in deposit/withdraw/emergencyWithdraw
rule userInfo_amount_safe_mutate(method f) {
    assert false, "not yet implemented";
}

// rJoePerSec only changed by owner in updateEmissionRate
rule RJPS_only_owner_and_function(method f) {
    assert false, "not yet implemented";
    // RJPS_pre
    f(e, args);
    // RJPS_post

    // RJPS_post != RJPS_pre => f is updateEmissionRate
}

// pendingReward[user] only decreased by user
rule pending_reward_decreased_only_user() {
    assert false, "not yet implemented";
    // deposit joe 
    // storage state
    // pendingRJoe for delta_t1
    // pendingRJoe for delta_t2 at storage state
    // t2 > t1 =? pendringRJoe2 > pendingRjoe1
}

//  - If I am staked, I get some RJoe
rule staking_non-trivial_rJoe() {
    assert false, "not yet implemented";
    // deposit joe
    // delta_t > 0 (for t = 0 I should have no rewards)
    // pendingRJoe > 0
}

//  - If I stake longer, I get more reward
rule stake_duration_correlates_return() {
    assert false, "not yet implemented";
}

//  - No front-running for deposit:   `f(); deposit(...)` has same result as `deposit()`)
rule deposit_no_frontrunning() {
    assert false, "not yet implemented";
    // storage state

    f(e, args); 
    // deposit

    // deposit again at storage state

    // compare results
}
//  - No front-running for withdraw   `f(); withdraw(...)` has same result as `withdraw()`)
rule withdraw_no_frontrunning(method f) {
    assert false, "not yet implemented";

    // storage state

    // withdraw

    f(e, args);

    // withdraw again at storage state

    // compare results
}

// additivty with frontrunning for greater coverage?
rule additivity_withdraw() {
    assert false, "not yet implemented";

    // storage state init 

    // withdraw x + y

    // withdraw x
    // withdraw y

    // compare results
}

rule additivity_deposit() {
    assert false, "noet yet implemented";

    // storage state init

    // deopsit x
    // deposit y

    // deposit xy at storage state

    // compare results
}

//  - updatePool is a no-op (`updatePool(); f(...)` has same result as `f()`)
//  - rJoe.totalSupply increasing at constant rate (rJoePerSec)
//  - If I stake for 0 time, I get no reward
//  - deposit and withdraw are both additive
