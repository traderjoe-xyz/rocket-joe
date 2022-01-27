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
    uint256 joe;
    require joe > 0;
    env e0;
    deposit(e0, joe);

    env e1; 
    int delta_t = e1.msg.sender - e0.msg.sender; // store this as a variable for more readable cex
    require delta_t > 0;
    uint256 rJoe = pendingRJoe(e1, e0.msg.sender);
    assert rJoe != 0;
}

//  - If I stake longer, I get more reward
rule stake_duration_correlates_return() {

    storage init; 
    uint256 joe;
    require joe > 0;
    env e0;
    deposit(e0, joe);

    env e1; 
    int delta_t1 = e1.msg.sender - e0.msg.sender; // store this as a variable for more readable cex
    require delta_t1 > 0;
    uint256 rJoe1 = pendingRJoe(e1, e0.msg.sender);

    deposit(e0, joe) at init;

    env e3; 
    int delta_t2 = e2.msg.sender - e0.msg.sender; // store this as a variable for more readable cex
    require delta_t2 > delta_t1;
    uint256 rJoe2 = pendingRJoe(e2, e0.msg.sender);

    assert delta_t2 > delta_t1 => rJoe2 > rJoe1; 
}

//  - No front-running for deposit:   `f(); deposit(...)` has same result as `deposit()`)
rule deposit_no_frontrunning() filtered { f-> (f.selector != withdraw(uint256).selector &&
                                                       f.selector != deposit(uint256).selector)
}{
    env e;
    uint256 x;
    storage init;

    f(e, args);
    deposit(e, x);
    uint256 bal_f = userJoe(e.msg.sender);

    deposit(e, x) at init;
    uint256 bal_clean = userJoe(e.msg.sender);
    assert bal_f == bal_clean, "frontrunning found";
}
//  - No front-running for withdraw   `f(); withdraw(...)` has same result as `withdraw()`)
rule withdraw_no_frontrunning(method f) filtered { f-> (f.selector != withdraw(uint256).selector &&
                                                       f.selector != deposit(uint256).selector)
}{
    env e;
    uint256 x;
    storage init;

    f(e, args);
    withdraw(e, x);
    uint256 bal_f = userJoe(e.msg.sender);

    withdraw(e, x) at init;
    uint256 bal_clean = userJoe(e.msg.sender);
    assert bal_f == bal_clean, "frontrunning found";
}

// additivty with frontrunning for greater coverage?
rule additivity_withdraw() {
    uint256 x;
    uint256 y;
    env e; 
    require x > 0 && y > 0;
    require userJoe > x + y;

    storage init;

    withdraw(e, x);
    withdraw(e, y);

    uint256 bal_sep = userJoe(e.msg.sender);

    withdraw(e, x+y) at init;
    uint256 bal_sum = userJoe(e.msg.sender);
    
    assert bal_sep == bal_sum, "additivity failed";
}

rule additivity_deposit() {
    uint256 x;
    uint256 y;
    env e; 
    require x > 0 && y > 0;

    storage init;

    deposit(e, x);
    deposit(e, y);

    uint256 bal_sep = userJoe(e.msg.sender);

    deposit(e, x+y) at init;
    uint256 bal_sum = userJoe(e.msg.sender);

    assert bal_sep == bal_sum, "additivity failed";

}

//  - updatePool is a no-op (`updatePool(); f(...)` has same result as `f()`)
//  - rJoe.totalSupply increasing at constant rate (rJoePerSec)
//  - If I stake for 0 time, I get no reward
//  - deposit and withdraw are both additive
