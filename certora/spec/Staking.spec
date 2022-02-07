import "../helpers/erc20.spec"

////////////////////////////////////////////////////////////////////////////
//                      Methods                                           //
////////////////////////////////////////////////////////////////////////////
using DummyERC20Impl as Joe

using RocketJoeToken as RJoe

methods {
    // external functions
    mint(address, uint256) returns (uint256) => DISPATCHER(true) // does not seem to be functioning

    // generated getters 
    lastRewardTimestamp() returns (uint256) envfree
    accRJoePerShare() returns (uint256) envfree
    rJoePerSec() returns (uint256) envfree
    // mapping(address => UserInfo) public userInfo;
    // Initialize(IERC20Upgradeable _joe, RocketJoeToken _rJoe, uint256 _rJoePerSec)
    
    // internal functions
    pendingRJoe(address) returns (uint256)
    deposit(uint256)
    withdraw(uint256)
    emergencyWithdraw()
    updatePool()
    updateEmissionRate(uint256)
    // _safeRJoeTransfer(address, uint256) // internal

    // harness functions
    userJoeStaked(address) returns (uint256) envfree
    userRewardDebt(address) returns (uint256) envfree
    getOwner() returns (address) envfree
    PRECISION() returns (uint256) envfree
}

rule sanity(method f) {
    env e; calldataarg args;
    f(e, args);
    assert false;
}

ghost sum_user_balance() returns uint256;
// {
//     init_state axiom sum_user_balance() == 0;
// }

ghost sum_user_rewards() returns uint256;
// {
//     init_state axiom sum_user_rewards() == 0;
// }

// user sum balance hook
hook Sstore userInfo[KEY address user].amount uint256 userBalance (uint256 oldUserBalance) STORAGE {
    havoc sum_user_balance assuming
        sum_user_balance@new() == sum_user_balance@old() + userBalance - oldUserBalance;
}

hook Sstore RJoe._balances[KEY address user] uint256 reward (uint256 oldReward) STORAGE {
    havoc sum_user_rewards assuming
        sum_user_rewards@new() == sum_user_rewards@old() + reward - oldReward;
}

// initialization invariance 

ghost initialized()  returns bool;

hook Sstore _initialized bool init STORAGE {
  havoc initialized assuming initialized@new() == init;
}

invariant is_initialized()
    initialized()

invariant precision_nonzero()
    PRECISION() > 0

////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////

// // rJoe.totalSupply is sum of rJoe balances
// invariant User_RJ_balance_sums_supply()
//     false

// rule
//rJoe.balanceOf(RJStaking) ≥ Σ pendingRewards over all users
invariant staking_RJ_balance_eq_pending_rewards(env e)
    RJoe.balanceOf(e, currentContract) >= sum_user_rewards()

//joe.balanceOf(RJStaking)  ≥ Σ userInfo[user].amount
invariant staking_joe_bal_sums_user_balance(env e)
    Joe.balanceOf(e, currentContract) >= sum_user_balance()

// non-zero e.msg.sender implies a non-zero reward debt?

////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

// I'd like to do an invariant that shows this is always increasing, but I can't see a good way to do so
rule updatePool_increases_accRJoePerShare() {
    requireInvariant precision_nonzero();
    env e;
    require e.block.timestamp > lastRewardTimestamp();
    require Joe.balanceOf(e, currentContract) > 0; // will not increase if supply is 0
    uint256 pre = accRJoePerShare();
    updatePool(e);
    uint256 post = accRJoePerShare();
    assert post > pre, "acc not increasing";
}

//userInfo[user].amount only changed by user in deposit/withdraw/emergencyWithdraw
rule userInfo_amount_safe_mutate(method f) {
    env e; calldataarg args;
    address user;
    uint256 userBalance_pre = userJoeStaked(user);
    f(e, args);
    uint256 userBalance_post = userJoeStaked(user);
    assert userBalance_pre != userBalance_post => f.selector == deposit(uint256).selector ||
                                            f.selector == withdraw(uint256).selector ||
                                            f.selector == emergencyWithdraw().selector, "improper function mutated user balance";
    assert userBalance_pre != userBalance_post => e.msg.sender == user, "non-user mutated balance";

}

// rJoePerSec only changed by owner in updateEmissionRate
rule RJPS_only_owner_and_function(method f) //  filtered { f -> f.selector != 0xeb990c59} 
{
    requireInvariant is_initialized();
    env e; calldataarg args;
    uint256 RJPS_pre = rJoePerSec();
    f(e, args);
    uint256 RJPS_post = rJoePerSec();

    assert RJPS_post != RJPS_pre => f.selector == updateEmissionRate(uint256).selector, "changed by wrong function";
    assert RJPS_post != RJPS_pre => e.msg.sender == getOwner(), "changed by non-owner";
}

// pendingReward[user] only decreased by user
rule pending_reward_decreased_only_user(method f) {
    requireInvariant is_initialized();
    env e; calldataarg args;
    address user;
    uint256 rjoe_pre = pendingRJoe(e, user);
    f(e, args);
    uint256 rjoe_post = pendingRJoe(e, user);
    assert rjoe_post < rjoe_pre => e.msg.sender == user; 
}

//  - If I am staked, I get some RJoe
rule staking_non_trivial_rJoe() {
    uint256 joe;
    require joe > 0;
    env e0;
    env e1;
    require e0.msg.sender == e1.msg.sender; 
    require e1.block.timestamp > e0.block.timestamp;
    require userRewardDebt(e0.msg.sender) < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // todo find the maxuint256 function and use that
    uint delta_t = e1.block.timestamp - e0.block.timestamp; // store this as a variable for more readable cex


    deposit(e0, joe);
    uint256 rJoe = pendingRJoe(e1, e0.msg.sender);
    assert rJoe != 0, "trivial rJoe";
}

rule staking_trivial_on_zero_time() {
    uint256 joe;
    require joe > 0;
    env e0;
    deposit(e0, joe);

    env e1; 
    uint delta_t = e1.block.timestamp - e0.block.timestamp; // store this as a variable for more readable cex
    require delta_t == 0; 
    uint256 rJoe = pendingRJoe(e1, e0.msg.sender);
    assert rJoe == 0, "RJOE gained with no stake time";
}

//  - If I stake longer, I get more reward
rule stake_duration_correlates_return() {

    storage init = lastStorage; 
    uint256 joe;
    require joe > 0;
    env e0;
    env e1; 
    env e2; 

    // accessing the same account, not current contract
    require e0.msg.sender != currentContract && e1.msg.sender == e0.msg.sender && e2.msg.sender == e0.msg.sender;
    // account 2 stakes longer than account 1, which stakes more than 0 seconds
    require e1.block.timestamp > e0.block.timestamp && e2.block.timestamp > e1.block.timestamp;

    deposit(e0, joe);
    uint256 rJoe1 = pendingRJoe(e1, e0.msg.sender);
    deposit(e0, joe) at init;
    uint256 rJoe2 = pendingRJoe(e2, e0.msg.sender);

    assert rJoe2 > rJoe1; 
}

//  - No front-running for deposit:   `f(); deposit(...)` has same result as `deposit()`)
rule deposit_no_frontrunning(method f)
{
    // setup
    env e; calldataarg args;
    uint256 x;
    require userJoeStaked(currentContract) > x;
    uint256 bal_pre_clean = userJoeStaked(e.msg.sender);
    storage init = lastStorage;

    // run with frontrunning
    f(e, args);
    require userJoeStaked(currentContract) > x;
    uint256 bal_pre_f = userJoeStaked(e.msg.sender);
    deposit(e, x);
    uint256 bal_post_f = userJoeStaked(e.msg.sender);
    uint256 delta_f = bal_post_f - bal_pre_f;

    // run without frontrunning
    deposit(e, x) at init;
    uint256 bal_post_clean = userJoeStaked(e.msg.sender);
    uint256 delta_clean = bal_post_clean - bal_pre_clean;

    assert delta_f == delta_clean, "frontrunning found";
}
//  - No front-running for withdraw   `f(); withdraw(...)` has same result as `withdraw()`)
rule withdraw_no_frontrunning(method f) filtered { f-> (f.selector != emergencyWithdraw().selector)}
{
    // setup
    env e; calldataarg args;
    uint256 x;
    require userJoeStaked(currentContract) > x;
    uint256 bal_pre_clean =  userJoeStaked(e.msg.sender);
    storage init = lastStorage;

    // run with frontrunning
    f(e, args);
    require userJoeStaked(currentContract) > x;
    uint256 bal_pre_f = userJoeStaked(e.msg.sender);
    withdraw(e, x);
    uint256 bal_post_f = userJoeStaked(e.msg.sender);
    uint256 delta_f = bal_pre_f - bal_post_f;

    // run without fruntrunning
    withdraw(e, x) at init;
    uint256 bal_post_clean = userJoeStaked(e.msg.sender);
    uint256 delta_clean = bal_pre_clean - bal_post_clean;

    assert delta_f == delta_clean, "frontrunning found";
}

// additivty with frontrunning for greater coverage?
rule additivity_withdraw() {
    storage init = lastStorage;
    env e; 
    uint256 x;
    uint256 y;
    require x > 0 && y > 0;
    // require userJoeStakede.msg.sender) > x + y;
    withdraw(e, x);
    withdraw(e, y);

    uint256 bal_sep = userJoeStaked(e.msg.sender);

    withdraw(e, x+y) at init;
    uint256 bal_sum = userJoeStaked(e.msg.sender);
    
    assert bal_sep == bal_sum, "additivity failed";
}

rule additivity_deposit() {
    uint256 x;
    uint256 y;
    env e; 
    require x > 0 && y > 0;

    storage init = lastStorage;

    deposit(e, x);
    deposit(e, y);

    uint256 bal_sep = userJoeStaked(e.msg.sender);

    deposit(e, x+y) at init;
    uint256 bal_sum = userJoeStaked(e.msg.sender);

    assert bal_sep == bal_sum, "additivity failed";
}

rule verify_deposit() {
    env e;
    require e.msg.sender != currentContract;
    uint256 amount; 

    uint256 balance_pre = userJoeStaked(e.msg.sender);
    uint256 reward_debt_pre = userRewardDebt(e.msg.sender);
    deposit(e, amount);
    uint256 balance_post = userJoeStaked(e.msg.sender);
    uint256 reward_debt_post = userRewardDebt(e.msg.sender);

    assert balance_post - amount == balance_pre, "improper amount deposited";
    assert (e.block.timestamp > lastRewardTimestamp() => reward_debt_post > reward_debt_pre)  || userJoeStaked(e.msg.sender) == 0, "reward debt not increased";
    assert pendingRJoe(e, e.msg.sender) == 0, "user has unclaimed rewards";
}

rule verify_withdraw() {
    env e;
    require e.msg.sender != currentContract;
    uint256 amount; 

    uint256 balance_pre = userJoeStaked(e.msg.sender);
    uint256 reward_debt_pre = userRewardDebt(e.msg.sender);
    withdraw(e, amount);
    uint256 balance_post = userJoeStaked(e.msg.sender);
    uint256 reward_debt_post = userRewardDebt(e.msg.sender);

    assert balance_pre - amount == balance_post, "improper amount withdrawn";
    assert (e.block.timestamp > lastRewardTimestamp() => reward_debt_post > reward_debt_pre) || userJoeStaked(e.msg.sender) == 0, "reward debt not increased";
    assert pendingRJoe(e, e.msg.sender) == 0, "user has unclaimed rewards";
}

rule verify_updateEmissionRate {
    env e; 
    uint256 emissionRate;
    updateEmissionRate(e, emissionRate);
    assert rJoePerSec() == emissionRate, "emission rate not updated";
}

rule updatePool_contained() {
    env e;
    address user;
    uint256 balance_pre = userJoeStaked(user);
    uint256 reward_debt_pre = userRewardDebt(user);
    updatePool(e);
    assert userJoeStaked(user) == balance_pre, "balance changed";
    assert userRewardDebt(user) == reward_debt_pre, "reward debt changed";
}

rule verify_emergencyWithdraw() {
    env e;

    uint256 userJoe_pre = userJoeStaked(e.msg.sender);
    uint256 stakingJoe_pre = Joe.balanceOf(e, currentContract);

    emergencyWithdraw@withrevert(e);
    
    assert lastReverted == false, "failed, should not fail"; 
    assert userJoeStaked(e.msg.sender) == 0, "user still had joe remaining";
}

//  - updatePool is a no-op (`updatePool(); f(...)` has same result as `f()`)
//  - rJoe.totalSupply increasing at constant rate (rJoePerSec)