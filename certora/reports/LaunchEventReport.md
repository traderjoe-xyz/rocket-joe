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

### Bugs found and recommendations

TODO: Brief summary of bugs found and recommendations.  These can also be
included in the main report in the parent directory. This might include
stylistic or performance recommendations as well as bugs uncovered by the
rules.

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

This contract manages the following variable state:

 - Its WAVAX, launch token, and LP token balances
 - The WAVAX and LP token balances of the investors
 - The launch token and LP token balances of the issuer

 - The address of the LP token
 - Whether the launch has been stopped
 - The amount of AVAX an investor deposited
 - Whether the invester has withdrawn their LP tokens

 - The total amount of WAVAX and launch tokens in the pool immediately after creation
 - The total number of LP tokens minted during launch
 - The total number of launch tokens held in reserve immediately after launch

### States and Invariants

always:
 - getUA[issuer].allocation == 0

initialized (initialized is true):
 - appropriate constants nonzero

open (before createPair, not stopped):
 - pair is 0
 - getUA[user].hasWithdrawnPair is false
 - WAVAX balance of this == Σ getUA[user].allocation
 - avaxAllocated is 0
 - tokenAllocated is 0
 - lpSupply is 0
 - tokenReserve is fixed
 - tokenReserve is the token balance of this

closed (after createPair, not stopped):
 - pair is nonzero
 - isStopped is false
 - user hasWithdrawnPair <=> pair balance of user is nonzero [can be more specific]
 - avaxAllocated is Σ getUA[user].allocation
 - (getUA[user].allocation is constant)

 - WAVAX balance of this is 0
 - pair balance of this = sum of unwithdrawn lp tokens over all users (half to issuers, remainder to users)
     up to roundoff
 - token balance of this = sum of unwithdrawn reserve tokens (as above)

 - avaxAllocated, tokenAllocated, lpSupply, tokenReserve are unchanging

half of LP tokens go to issuer, other half go to users based on how much they deposited

### Method specifications

TODO

    function pairBalance(address _user) public view returns (uint256) {
    function currentPhase() public view returns (Phase) {
    function getPenalty()
    function getReserves()
    function getRJoeAmount(uint256 _avaxAmount)

    function initialize(...)
    function depositAVAX()
    function withdrawAVAX(uint256 _amount)
    function createPair()
    function withdrawLiquidity()
    function withdrawIncentives()
    function emergencyWithdraw()
    function allowEmergencyWithdraw()
    function skim()

methods
=======

createPair:
 - no tokens are lost (tokenReserve@after + tokenAllocated@after == tokenReserve@before)
 - pair balance of this + pair balance of issuer + Σ pair balance of user == lpSupply (maybe * exchange?)
 - token balance of this + token balance of issuer + Σ token balance of user == tokenReserve (maybe * exchange?)


createPair:
  Before:
    WAVAX/Pair: 0; WAVAX/this: avaxAllocated; Token/Pair: 0; Token/this: tokenReserve

  After:
    WAVAX/Pair: avaxAllocated; WAVAX/this: ?; Token/Pair: tokenAllocated; Token/this: tokenReserve

 - calls router.addLiquidity to create/configure pair and assign lp tokens to this
 - transfer all avax and tokens to pair, providing liquidity
 - uses the resulting balance of wavax and token on the pair to set the allocations
 - reduces the reserve (since some of the tokens have 


| Variable     | pre-init | initialized | phase 1 | phase 2 | pair created | post-timelock | stopped
| issuer       |          | Fixed
| auctionStart |          | Fixed, > timestamp | fixed, 
| 
```

(![status])[^footnoteName] `rule_name`
: Brief description

where `![status]` is replaced with one of the four images in ../MainReport.md
(passing, failing, todo, or timeout).  If any rules are failing or you need to
list additional notes (e.g. we didn't check this on the initialize method), you
can write the footnotes as follows:

[^footnoteName]:
    Here is an example footnote.

