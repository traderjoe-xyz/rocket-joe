---
breaks: false
---

## LaunchEvent Contract Verification Report

### Contract description

The LaunchEvent contract is used to collect AVAX from investors in preparation
for the creation of a new liquidity pool.  The contract manages 4 kinds of tokens:

 - **WAVAX** (`LaunchEvent.wavax`): Wrapped AVAX

 - **Launch tokens** (`LaunchEvent.token`): The new token being offered

 - **LP tokens** (`LaunchEvent.pair`): The tokens that allow investors to withdraw
   liquidity from the created pool

 - **RJoe** (`LaunchEvent.rJoe`): These tokens are required to invest in the launch

The launch proceeds in several phases:

 * Pre-start: an issuer creates the LaunchEvent contract and transfers some
   amount of launch tokens to it.

 * Phase 1: investors can deposit or withdraw AVAX, although withdrawals
   are penalized at a rate that increases over time.

 * Phase 2: no further deposits are allowed, but investors can withdraw their
   AVAX at a penalty

 * Phase 3: All invested AVAX and some of the launch token are used to create a
   liquidity pool.  The remaining launch token is held in reserve

 * Post-timelock: Half of the LPToken and half of the reserves are allocated to
   the issuer; the other half is divided among the investors.

The launch can also be cancelled by the issuer before phase 3, allowing
investors to withdraw their AVAX without penalty.

### Assumptions made during verification

TODO

### Important state variables

This contract manages the following variable state:

 - LaunchEvent balances: The WAVAX, launch token, and LP token balances of the LaunchEvent contract
 - Investor balances:    The WAVAX, LP and Launch(Incentives) token balances of the investors
 - Issuer balances:      The launch token and LP token balances of the issuer

 - `pair`:                     The address of the LP token
 - `isStopped`:                Whether the launch has been stopped
 - `getUI[user].allocation`:   The amount of AVAX an investor can deposit without burning rJoe
 - `getUI[user].balance`:   The amount of AVAX an investor deposited
 - `getUI[user].hasWithdrawnPair`: Whether the investor has withdrawn their LP tokens
 - `getUI[user].hasWithdrawnIncentives`: Whether the investor has withdrawn their incentives

 - `tokenIncentivesBalance`: The total amount of unwithdrawn incentives
 - `tokenIncentivesForUsers`: The total amount of incentives of users (excluding issuer)
 - `tokenIncentiveIssuerRefund`: Issuer incentives

 - `wavaxReserve`: The total amount of deposited WAVAX (before createPair())
 - `wavaxAllocated`: The total amount of WAVAX in the pool immediately after pair creation
 - `tokenReserve + tokenAllocated(local var of createPair())`: The total amount of launch tokens in the pool immediately after creation
 - `lpSupply`:       The total number of LP tokens minted during launch
 - `tokenReserve`:   The total number of launch tokens that will be used to create LP tokens

### States and Invariants

always:
 - getUI[issuer].allocation == 0
 - getUI[user].balance <= getUI[user].allocation
 - getUI[user].allocation <= maxAllocation
 - `address(token)` != `address(wavax)`


initialized (initialized is true):
 - `initialized` == true
 - `Phase.NotStarted`
 - `stopped` == false
 - appropriate constants nonzero:
        - `issuerTimelock` >= 1
        - `userTimelock` <= 7 days
        - `auctionStart` > block.timestamp
        - `PHASE_ONE_DURATION` == 2 days
        - `PHASE_ONE_NO_FEE_DURATION` == 1 day
        - `PHASE_TWO_DURATION` == 1 day
        - addresses: `issuer`, `token`, `rocketJoeFactory`, `WAVAX`, `router`, `factory`, `rJoe` (should be non-zero but there is no check for it, makes sense to write it?)
 - `issuerTimelock` > `userTimelock`
 - `tokenIncentivesForUsers` == `tokenIncentivesBalance`
 - `tokenReserve` + `tokenIncentivesForUsers` == `token.balanceOf(address(this))`
 - the rest is 0 or false (depends on a type)


open (pair is 0):
 - `pair` == 0
 - `pair` == `factory.getPair(wavaxAddress, tokenAddress)`
 - `Phase.PhaseOne` || `Phase.PhaseTwo`
 - `stopped` == false
 - `WAVAX.balanceOf(LaunchEvent)` == Σ getUI[user].balance == `wavaxReserve`
 - `token.balanceOf(LaunchEvent)` >= `tokenReserve` + `tokenIncentivesForUsers`
 - `getUI[user].hasWithdrawnPair` is false
 - `getUI[user].hasWithdrawnIncentives` is false
 - `pair`, `wavaxAllocated`, `lpSupply` are all 0


closed (pair is nonzero):
 - `pair` != 0
 - `pair` == `factory.getPair(wavaxAddress, tokenAddress)`
 - `Phase.PhaseThree`
 - `stopped` == false
 - `wavaxAllocated` == Σ getUI[user].balance
 - `wavaxReserve` == `WAVAX.balanceOf(LaunchEvent)` == 0
 - `pair.balanceOf(LaunchEvent)` >= sum of unwithdrawn lp tokens over all users (half to issuers, remainder to users)
     up to roundoff
 - `token.balanceOf(LaunchEvent)` >= sum of `tokenReserve` and unwithdrawn incentives     // @AK - "unwithdrawn reserve tokens" - waht do you mean?
 - `tokenIncentivesBalance` == `tokenIncentiveIssuerRefund` + `tokenIncentivesForUsers`
 - `tokenIncentivesBalance` <= `tokenIncentivesForUsers`


### Variable changes

open:
 - (balance changes governed by the invariants)
 - (pair, avaxAllocated, tokenAllocated, lpSupply, tokenReserve are governed by invariants)
 - getUI[user].balance only changed by user in deposit and withdraw (see method specs)
 - getUI[user].allocation only changed by user in deposit (see method specs)
 - getUI[user].allocation only increases
 - isStopped only changed by owner
 - `tokenReserve`, `tokenIncentivesBalance`, `tokenIncentivesForUsers`, `tokenIncentiveIssuerRefund` are unchanging


transitions:
 - `pair` only changes in `createPair` (see method spec)
 - `initialized` only changes in `initialize` (see method spec)
 - `tokenIncentivesForUsers` can only be change in `createPair()`
 - `tokenIncentiveIssuerRefund` cab only be change in `createPair()`


closed:
 - pair, wavaxAllocated, tokenAllocated, lpSupply, tokenReserve are unchanging
 - getUA[user].allocation is unchanging
 - hasWithdrawnPair and LP token balance of user are related; change only in withdrawLiquidity
 - hasWithdrawnIncentives and Launch token balance of user are related; change only in withdrawIncentives
 - isStopped changes only by owner
 - LP and launch token balance of LaunchEvent are decreasing, and at a proportional rate[^specify]          // @AK - but they can be changed by two different functions.
 - tokenIncentivesBalance can be 0 only if emergencyWithdraw() was called or all users withdrawn their incentives
 - `tokenIncentivesBalance` is non-increasing

The following variables are set to nonzero values during initialization and
remain fixed thereafter:

- Addresses:
  `issuer`
  `rJoe`
  `WAVAX`
  `token`
  `router`
  `factory`
  `rocketJoeFactory`

- Times:
  `auctionStart`
  `PHASE_ONE_DURATION`
  `PHASE_TWO_DURATION`
  `PHASE_ONE_NO_FEE_DURATION`
  `userTimelock`
  `issuerTimelock`

- Prices:
  `floorPrice`
  `fixedWithdrawPenalty`
  `rJoePerAvax`

- State
  `initialized`
  `maxAllocation`

// @AK - `floorPrice`, `userTimelock`, `fixedWithdrawPenalty`, `rJoePerAvax`, `maxAllocation` - can be 0. there are no checks for it.

### Method specifications

initialize(...)
 - changes `initialized` to true

 - reverts if initialized
 - reverts if arguments are invalid[^specify]
 - succeeds otherwise

function depositAVAX()
 - increases getUI[user].allocation by msg.value
 - burns appropriate amount of RJoe

 - reverts if user's RJoe balance is insufficient
 - reverts if getUI[user].allocation + msg.value is out of range[^specify]
 - reverts if not in PhaseOne
 - succeeds otherwise

function withdrawAVAX(amount)
 - decreases getUI[user].allocation by amount
 - increases user's WAVAX balance by at least (amount - penalty)[^specify]
 - decreases LaunchEvent's WAVAX balance by amount

 - reverts if getUI[user].allocation < amount
 - reverts if getUI[user].allocation - amount is out of range[^specify]
 - reverts if not in Phase1 or Phase2
 - succeeds otherwise

function createPair()
 - updates pair to a new pool
 - transfers all WAVAX to the pool
 - transfers enough launch token to the pool to ensure appropriate price[^specify]
 - transfers total supply of LP tokens to LaunchEvent
 - updates `pair`, `avaxAllocated`, `tokenAllocated`, `lpSupply` appropriately[^specify]
 - no tokens are lost (tokenReserve@after + tokenAllocated@after == tokenReserve@before)

 - reverts if pair already existed
 - succeeds otherwise

function withdrawLiquidity()
 - increases msg.sender's LP     token balance by their LP token allocation[^specify]
 - increases msg.sender's launch token balance by their launch token allocation[^specify]
 - sets getUI[msg.sender].hasWithdrawn to true

 - reverts if getUI[msg.sender].hasWithdrawn
 - reverts if time is before end of timelock[^specify]
 - succeeds otherwise

function emergencyWithdraw()
 - increases msg.sender's WAVAX balance by getUI[user].allocation
 - sets getUI[msg.sender].allocation to 0

 - reverts if LaunchEvent isn't stopped
 - succeeds otherwise

function allowEmergencyWithdraw()
 - sets isStopped to true

 - reverts if msg.sender  is not owner
 - reverts if LaunchEvent is in PhaseThree
 - succeeds otherwise

### High level rules

- pair balance of this == pair balance of issuer + Σ pair balance of user  == lpSupply == pair.totalSupply        // @AK - changed, need double check
- token balance of this == tokenReserve + tokenIncentivesBalance // @AK - I don't agree: == token balance of issuer + Σ token balance of user. Users have nothing. changed, need double check
- additivity of deposit:   deposit(a);  deposit(b)  has same effect as deposit(a+b)
- additivity of withdraw:  withdraw(a); withdraw(b) has same effect as withdraw(a+b)
- if I deposit more AVAX, I receive more LP and launch tokens
- if I withdraw AVAX later, I have a larger penalty
- deposit and withdraw are two-sided inverses on the state (if successful)

- no front-running for deposit: effect of deposit unchanged by an intervening operation by another user
- no front-running for withdraw
- no front-running for withdrawLiquidity
- createPair can be called at least once (DoS check)

- if someone withdrawn during day 2 or 3, then `WAVAX.balanceOf(penaltyCollector)` > 0
 - user doesn't burn more rJoes than needed (with ghost probably)   @AK - is it possible?
 - `lpSupply` > 0 if `wavaxReserve` > 0 and `tokenReserve` > 0

### Template stuff

(![status])[^footnoteName] `rule_name`
: Brief description

where `![status]` is replaced with one of the four images in ../MainReport.md
(passing, failing, todo, or timeout).  If any rules are failing or you need to
list additional notes (e.g. we didn't check this on the initialize method), you
can write the footnotes as follows:

[^footnoteName]:
    Here is an example footnote.

[^specify]:
    This term is not defined.

