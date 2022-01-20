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

 * Phase 2: no further deposits are allowed, but investers can withdraw their
   AVAX at a penalty

 * Phase 3: All invested AVAX and some of the launch token are used to create a
   liquidity pool.  The remaining launch token is held in reserve

 * Post-timelock: Half of the LPToken and half of the reserves are allocated to
   the issuer; the other half is divided among the investors.

The launch can also be cancelled by the issuer before phase 3, allowing
investors to withdraw their AVAX without penalty.

### Assumptions made during verification

TODO: Description of the assumptions underlying each method summary, harnessed
method, or other unsound approximation, and an explanation of why they are
reasonable.  For example, a NONDET summary might mean that we assume that an
external contract does not make calls back into the current contract, or a
DISPATCHER summary might indicate that we assume that external tokens behave
according to some specification (e.g. ERC20).

TODO: The goal of this section is that if we miss any bugs that break our rules, we
should be able to point to an explicit assumption in this list to explain what
assumption doesn't actually hold.

### Important state variables

This contract manages the following variable state:

 - LaunchEvent balances: The WAVAX, launch token, and LP token balances of the LaunchEvent contract
 - Investor balances:    The WAVAX and LP token balances of the investors
 - Issuer balances:      The launch token and LP token balances of the issuer

 - `pair`:                     The address of the LP token
 - `isStopped`:                Whether the launch has been stopped
 - `getUI[user].allocation`:   The amount of AVAX an investor deposited
 - `getUI[user].hasWithdrawn`: Whether the invester has withdrawn their LP tokens

 - `wavaxAllocated`: The total amount of WAVAX and launch tokens in the pool immediately after creation
 - `lpSupply`:       The total number of LP tokens minted during launch
 - `totalReserve`:   The total number of launch tokens held in reserve immediately after launch

### States and Invariants

always:
 - getUI[issuer].allocation == 0

initialized (initialized is true):
 - appropriate constants nonzero

open (pair is 0):
 - WAVAX balance of LaunchEvent >= Σ getUI[user].allocation
 - token balance of LaunchEvent >= tokenReserve
 - getUI[user].allocation is 0 or `minAllocation <= getUI[user].allocation <= maxAllocation`
 - `getUI[user].hasWithdrawnPair` is false
 - `pair`, `avaxAllocated`, `tokenAllocated`, `lpSupply` are all 0

closed (pair is nonzero):
 - isStopped is false
 - avaxAllocated is Σ getUI[user].allocation

 - WAVAX balance of this is 0
 - LP token balance of LaunchEvent >= sum of unwithdrawn lp tokens over all users (half to issuers, remainder to users)
     up to roundoff
 - token balance of LaunchEvent >= sum of unwithdrawn reserve tokens (as above)

### Variable changes

open:
 - (balance changes governed by the invariants)
 - (pair, avaxAllocated, tokenAllocated, lpSupply, tokenReserve are governed by invariants)
 - getUI[user].allocation only changed by user in deposit and withdraw (see method specs)
 - getUI[user].allocation only increases in PhaseOne
 - isStopped only changed by owner
 - tokenReserve is unchanging
 - changes only happen in Phase1 or Phase2

transitions:
 - `pair` only changes in `createPair` (see method spec)
 - `initialized` only changes in `initialize` (see method spec)

closed:
 - pair, avaxAllocated, tokenAllocated, lpSupply, tokenReserve are unchanging
 - getUA[user].allocation is unchanging
 - hasWithdrawnPair and LP token balance of user are related; change only in withdrawLiquidity
 - isStopped changes only by owner
 - user.hasWithdrawn changes only in `withdrawLiquidity` (see method spec)

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
  `userTimelock`
  `issuerTimelock`

- Prices:
  `floorPrice`
  `withdrawPenaltyGradient`
  `fixedWithdrawPenalty`
  `rJoePerAvax`

- State
  `initialized`
  `minAllocation`
  `maxAllocation`

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
  - increases user's WAVAX balance by at least (amount - penalty)
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

High level rules
================

- pair balance of this  + pair balance of issuer  + Σ pair balance of user  == lpSupply == pair.totalSupply * exchange[^specify]
- token balance of this + token balance of issuer + Σ token balance of user == tokenReserve * exchange[^specify]

- if a user 



From confluence:
================

High-level rules

If a user stakes more LP tokens

nontriviality: after depositAVAX, can withdrawAVAX

positive correlation between deposits and LPTokens

before createPair (WAVAX, Launch token)

no front-running for depositAVAX and withdrawAVAX (module penalty)

after depositAVAX, can withdrawAVAX

additivity of withdraw and deposit

Check that FeeAmount cannot exceed values presented in readme. If it can exceed it than a user can lose more than expected

after createPair (reserve, LP token)

After createPair, reserves and LP tokens are decreasing (at same rate)

no front-running for withdrawLiquidity: same result for withdrawLiquidity unaffected by other methods (TODO: think carefully about emergencyWithdraw)

Invariants

is it possible exceed max allocation?

Transitions

Balance of launch tokens is non-decreasing until the state reaches phase 3, with createPair called, and the token lock period passed 

Should the balance of launch token sent to the liquidity pool be a one time transaction, or can they continue to add to it? Allowing the ipo to add more token to the launch would allow to manipulate the launch price of AVAX / token, which could be good for the system but also could allow for some dangerous manipulation

Create Pair may only be called once

Method specs

can withdraw without penalty between 25 and 96 hours?

Ask Nurit

LaunchEvent

total assets of user is preservedtoken.balanceOf(user) + pairBalance(msg.sedner) 

where msg.sender is the user who called the withdrawLiquidity function and user = getUserAllocation[msg.sender].

Template stuff
==============

(![status])[^footnoteName] `rule_name`
: Brief description

where `![status]` is replaced with one of the four images in ../MainReport.md
(passing, failing, todo, or timeout).  If any rules are failing or you need to
list additional notes (e.g. we didn't check this on the initialize method), you
can write the footnotes as follows:

[^footnoteName]:
    Here is an example footnote.

