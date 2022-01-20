---
breaks: false
---

## RocketJoeStaking Contract Verification Report

### Contract description

The RocketJoeStaking contract is used to distribute reward tokens to investers
who stake Joe tokens.  RJoe tokens are added to the supply at a fixed rate, and
the supply is allocated to all staked users in proportion to their stake.  The
RJoe tokens are transferred to the users whenever they deposit or withdraw.

### Assumptions made during verification

TODO

### Important state variables

 - JOE balance of RJStaking
 - all rJOE balances
 - rJoePerSec

 - userInfo[user].amount
 - pendingReward(user)

### High level rules

 - updatePool is a no-op (`updatePool(); f(...)` has same result as `f()`)
 - rJoe.totalSupply increasing at constant rate (rJoePerSec)
 - If I am staked, I get some RJoe
 - If I stake longer, I get more reward
 - If I stake for 0 time, I get no reward
 - deposit and withdraw are both additive
 - No front-running for deposit:   `f(); deposit(...)` has same result as `deposit()`)
 - No front-running for withdraw   `f(); withdraw(...)` has same result as `withdraw()`)

### States and Invariants

 - rJoe.totalSupply is sum of rJoe balances
 - rJoe.balanceOf(RJStaking) ≥ Σ pendingRewards over all users
 - joe.balanceOf(RJStaking)  ≥ Σ userInfo[user].amount

### Variable changes

 - userInfo[user].amount only changed by user in deposit/withdraw/emergencyWithdraw
 - rJoePerSec only changed by owner in updateEmissionRate
 - pendingReward[user] only decreased by user

### Method specifications

    function deposit(uint256 _amount)
      - mints some RJToken
      - transfers `amount` of joe from msg.sender to RJStaking
      - transfers `pendingReward(msg.sender)` RJoe from RJStaking to msg.sender
      - sets `pendingReward(msg.sender)` to 0

      - reverts on overflow[^specify]
      - succeeds otherwise

    function withdraw(uint256 _amount)
      - mints some RJToken
      - transfers `amount` of joe from RJStaking to msg.sender
      - transfers `pendingReward(msg.sender)` RJoe from RJStaking to msg.sender
      - sets `pendingReward(msg.sender)` to 0

      - reverts on overflow[^specify]
      - reverts if userInfo[user].amount < _amount
      - succeeds otherwise

    function emergencyWithdraw()
      - transfers userInfo[msg.sender].amount of JOE from RJStaking to msg.sender
      - sets pendingReward(msg.sender) and userInfo[msg.sender].amount to 0

      - always succeeds

    function updateEmissionRate(uint256 _rJoePerSec)
      - changes rJoePerSec to _rJoePerSec

      - reverts if msg.sender is not owner
      - succeeds otherwise

    function updatePool()
      - has no visible effect

