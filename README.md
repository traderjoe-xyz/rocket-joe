# Rocket Joe

_Rocket Joe_ is a token launch platform where participants bid to provide liquidity for newly issued tokens. The platform enables price discovery and token distribution over a period of time before tokens are issued to public market, while discouraging front-running by bots. In addition, it improves liquidity sustainability by allowing issuing protocols to acquire its own token liquidity.

## How It Works

- User stakes JOE into the RocketJoeStaking contract to earn rJOE.
- LaunchEvent is created with a fixed amount of tokens to be issued.
- Users can deposit AVAX and rJOE into the LaunchEvent contract. The amount of rJOE needed to deposit a certain amount of AVAX is dictated by the parameter `rJoePerAvax`, which may vary from launch event to launch event.
- Users can also withdraw AVAX (if they think the price of TOKEN/AVAX is too high), but a withdrawal penalty may be incurred depending on which phase the launch event is at:

| Phase One  |                                   | Phase Two   |
| ---------- | --------------------------------- | ----------- |
| 0-24 hrs   | 24-72 hrs                         | 72-96 hrs   |
| 0% penalty | 0-50% penalty (linear increasing) | 20% penalty |

- **Phase One**:
  - 0-24 hrs: Users can deposit and withdraw AVAX without any penalty.
  - 24-72 hrs: Users can continue to deposit and withdraw AVAX, but must incur a withdrawal penalty that increases linearly from 0-50%.
- **Phase Two**: Users can _only_ withdraw AVAX with a 20% penalty.
- **Phase Three**: Initial liquidity is seeded, but the LP tokens are locked for an additional 3-7 days. After this phase, both user and issuer are free to claim their LP tokens.

## Contracts

![Rocket Joe contract flow](assets/Rocket_Joe.jpeg)

###### RocketJoeToken

An infinite supply ERC20 token that is an allocation credit for users to participate in a Launch Event. The amount of rJOE required to deposit an amount of AVAX into a launch event is dictated by `rJoePerAvax`, which is set manually on RocketJoeFactory. Once AVAX is deposited, rJOE is burned.

###### RocketJoeStaking

A MasterChef-style staking contract in which users stake JOE to earn rJOE.

###### RocketJoeFactory

Creates individual LaunchEvent contracts. Also sets `rJoePerAvax`.

###### LaunchEvent

Contract in which price discovery and token distribution takes place. Issuer deposits the issued tokens and users deposit and/or withdraw AVAX during a 96 hour period. The final amount of AVAX at the end of this period dictates the TOKEN/AVAX price which will be used to the seed initial liquidity on the Trader Joe.

## Installation

The first things you need to do are cloning this repository and installing its
dependencies:

```sh
git clone https://github.com/traderjoe-xyz/rocket-joe.git
cd rocket-joe
yarn
```

## Testing

To run the tests run:

```sh
make test
```

There is a pending bug with `solidity-coverage`. To get around this bug, you must manually edit `node_modules/solidity-coverage/plugins/hardhat.plugin.js` according to these [edits](https://github.com/sc-forks/solidity-coverage/pull/667/files).

Then to run coverage:

```sh
make coverage
```

The coverage report will then be found in `coverage/`.
