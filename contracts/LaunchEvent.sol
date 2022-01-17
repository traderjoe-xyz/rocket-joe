// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IJoeFactory.sol";
import "./interfaces/IJoePair.sol";
import "./interfaces/IJoeRouter02.sol";
import "./interfaces/IRocketJoeFactory.sol";
import "./interfaces/IRocketJoeToken.sol";
import "./interfaces/IWAVAX.sol";

/// @title Rocket Joe Launch Event
/// @author Trader Joe
/// @notice A liquidity launch contract enabling price discovery and token distribution at secondary market listing price
contract LaunchEvent is Ownable {
    /// @notice The phases the launch event can be in
    /// @dev Should these have more semantic names: Bid, Cancel, Withdraw
    enum Phase {
        NotStarted,
        PhaseOne,
        PhaseTwo,
        PhaseThree
    }

    struct UserAllocation {
        uint256 allocation;
        uint256 balance;
        bool hasWithdrawnPair;
    }

    /// @notice Issuer of sale tokens
    address public issuer;

    /// @notice The start time of phase 1
    uint256 public auctionStart;

    uint256 public PHASE_ONE_DURATION;
    uint256 public PHASE_TWO_DURATION;

    /// @notice Floor price in AVAX per token (can be 0)
    /// @dev floorPrice is scaled to 1e18
    uint256 public floorPrice;

    /// @notice Timelock duration post phase 3 when can user withdraw their LP tokens
    uint256 public userTimelock;

    /// @notice Timelock duration post phase 3 When can issuer withdraw their LP tokens
    uint256 public issuerTimelock;

    /// @notice The max withdraw penalty during phase 1, in parts per 1e18
    /// e.g. max penalty of 50% `maxWithdrawPenalty`= 5e17
    uint256 public maxWithdrawPenalty;

    /// @notice The fixed withdraw penalty during phase 2, in parts per 1e18
    /// e.g. fixed penalty of 20% `fixedWithdrawPenalty = 2e17`
    uint256 public fixedWithdrawPenalty;

    IRocketJoeToken public rJoe;
    uint256 public rJoePerAvax;
    IWAVAX private WAVAX;
    IERC20Metadata public token;

    IJoeRouter02 private router;
    IJoeFactory private factory;
    IRocketJoeFactory public rocketJoeFactory;

    bool private initialized;
    bool public stopped;

    uint256 public maxAllocation;

    mapping(address => UserAllocation) public getUserAllocation;

    /// @dev The address of the JoePair, set after createLiquidityPool is called
    IJoePair public pair;

    uint256 private avaxAllocated;
    uint256 private lpSupply;

    /// @dev Used to know how many issuing tokens will be sent to JoeRouter to create the initial
    /// liquidity pair. If floor price is not met, we will send fewer issuing tokens and `tokenReserve`
    /// will keep track of the leftover amount. It's then used to calculate the number of tokens needed
    /// to be sent to both issuer and users (if there are leftovers and every token is sent to the pair,
    /// tokenReserve will be equal to 0)
    uint256 private tokenReserve;

    /// @dev The exact amount of tokens needed to be kept inside the contract in order to send
    /// everyone's tokens. If there is any excess (because someone sent token directly to the contract), the
    /// penaltyCollector can collect the excess using `skim()`.
    /// It's *always* equal to tokenReserve before creating the pair. After pair is created, if tokenReserve > 0, i.e.
    /// because the floor price is not met, we update tokenBalance to be the exact amount of token minus
    /// what was already sent to users
    uint256 private tokenBalance;

    /// @dev wavaxBalance is the exact amount of WAVAX that needs to be kept inside the contract in order to send everyone's
    /// WAVAX. If there is some excess (because someone sent token directly to the contract), the
    /// penaltyCollector can collect the excess using `skim()`
    uint256 private wavaxBalance;

    event IssuingTokenDeposited(address indexed token, uint256 amount);

    event UserParticipated(
        address indexed user,
        uint256 avaxAmount,
        uint256 rJoeAmount
    );

    event UserWithdrawn(address indexed user, uint256 avaxAmount);

    event LiquidityPoolCreated(
        address indexed pair,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1
    );

    event UserLiquidityWithdrawn(
        address indexed user,
        address indexed pair,
        uint256 amount
    );

    event IssuerLiquidityWithdrawn(
        address indexed issuer,
        address indexed pair,
        uint256 amount
    );

    event Stopped();

    event AvaxEmergencyWithdraw(address indexed user, uint256 amount);

    event TokenEmergencyWithdraw(address indexed user, uint256 amount);

    /// @notice Receive AVAX from the WAVAX contract
    /// @dev Needed for withdrawing from WAVAX contract
    receive() external payable {
        require(
            msg.sender == address(WAVAX),
            "LaunchEvent: you can't send AVAX directly to this contract"
        );
    }

    /// @notice Modifier which ensures contract is in a defined phase
    modifier atPhase(Phase _phase) {
        _atPhase(_phase);
        _;
    }

    /// @notice Modifier which ensures the caller's timelock to withdraw has elapsed
    modifier timelockElapsed() {
        uint256 phase3Start = auctionStart +
            PHASE_ONE_DURATION +
            PHASE_TWO_DURATION;
        require(
            block.timestamp > phase3Start + userTimelock,
            "LaunchEvent: can't withdraw before user's timelock"
        );
        if (msg.sender == issuer) {
            require(
                block.timestamp > phase3Start + issuerTimelock,
                "LaunchEvent: can't withdraw before issuer's timelock"
            );
        }
        _;
    }

    /// @notice Ensures launch event is stopped/running
    modifier isStopped(bool _stopped) {
        if (_stopped) {
            require(stopped, "LaunchEvent: is still running");
        } else {
            require(!stopped, "LaunchEvent: stopped");
        }
        _;
    }

    /// @notice Initialise the launch event with needed paramaters
    /// @param _issuer Address of the token issuer
    /// @param _auctionStart The start time of the auction
    /// @param _token The contract address of auctioned token
    /// @param _floorPrice The minimum price the token is sold at
    /// @param _maxWithdrawPenalty The max withdraw penalty during phase 1, in parts per 1e18
    /// @param _fixedWithdrawPenalty The fixed withdraw penalty during phase 2, in parts per 1e18
    /// @param _maxAllocation The maximum amount of AVAX depositable
    /// @param _userTimelock The time a user must wait after auction ends to withdraw liquidity
    /// @param _issuerTimelock The time the issuer must wait after auction ends to withdraw liquidity
    /// @dev This function is called by the factory immediately after it creates the contract instance
    function initialize(
        address _issuer,
        uint256 _auctionStart,
        address _token,
        uint256 _floorPrice,
        uint256 _maxWithdrawPenalty,
        uint256 _fixedWithdrawPenalty,
        uint256 _maxAllocation,
        uint256 _userTimelock,
        uint256 _issuerTimelock
    ) external atPhase(Phase.NotStarted) {
        require(!initialized, "LaunchEvent: already initialized");

        rocketJoeFactory = IRocketJoeFactory(msg.sender);
        WAVAX = IWAVAX(rocketJoeFactory.wavax());
        router = IJoeRouter02(rocketJoeFactory.router());
        factory = IJoeFactory(rocketJoeFactory.factory());
        rJoe = IRocketJoeToken(rocketJoeFactory.rJoe());
        rJoePerAvax = rocketJoeFactory.rJoePerAvax();

        require(
            _maxWithdrawPenalty <= 5e17,
            "LaunchEvent: maxWithdrawPenalty too big"
        ); // 50%
        require(
            _fixedWithdrawPenalty <= 5e17,
            "LaunchEvent: fixedWithdrawPenalty too big"
        ); // 50%
        require(
            _userTimelock <= 7 days,
            "LaunchEvent: can't lock user LP for more than 7 days"
        );
        require(
            _issuerTimelock > _userTimelock,
            "LaunchEvent: issuer can't withdraw before users"
        );
        require(
            _auctionStart > block.timestamp,
            "LaunchEvent: start of phase 1 cannot be in the past"
        );

        issuer = _issuer;

        auctionStart = _auctionStart;
        PHASE_ONE_DURATION = rocketJoeFactory.PHASE_ONE_DURATION();
        PHASE_TWO_DURATION = rocketJoeFactory.PHASE_TWO_DURATION();
        token = IERC20Metadata(_token);
        tokenReserve = token.balanceOf(address(this));
        tokenBalance = tokenReserve;
        floorPrice = _floorPrice;

        maxWithdrawPenalty = _maxWithdrawPenalty;
        fixedWithdrawPenalty = _fixedWithdrawPenalty;

        maxAllocation = _maxAllocation;

        userTimelock = _userTimelock;
        issuerTimelock = _issuerTimelock;
        initialized = true;
    }

    /// @notice The current phase the auction is in
    function currentPhase() public view returns (Phase) {
        if (block.timestamp < auctionStart || auctionStart == 0) {
            return Phase.NotStarted;
        } else if (block.timestamp < auctionStart + PHASE_ONE_DURATION) {
            return Phase.PhaseOne;
        } else if (
            block.timestamp <
            auctionStart + PHASE_ONE_DURATION + PHASE_TWO_DURATION
        ) {
            return Phase.PhaseTwo;
        }
        return Phase.PhaseThree;
    }

    /// @notice Deposits AVAX and burns rJoe
    /// @dev Checks are done in the `_depositWAVAX` function
    function depositAVAX()
        external
        payable
        isStopped(false)
        atPhase(Phase.PhaseOne)
    {
        require(msg.sender != issuer, "LaunchEvent: issuer cannot participate");
        require(
            msg.value > 0,
            "LaunchEvent: expected non-zero AVAX to deposit"
        );

        UserAllocation storage user = getUserAllocation[msg.sender];
        require(
            user.balance + msg.value <= maxAllocation,
            "LaunchEvent: amount exceeds max allocation"
        );

        uint256 rJoeNeeded;
        uint256 requiredAllocation = user.balance + msg.value;
        // check if additional allocation is required.
        if (requiredAllocation > user.allocation) {
            // Burn tokens and update allocation.
            rJoeNeeded = getRJoeAmount(requiredAllocation - user.allocation);
            // Set allocation to the current balance as its impossible
            // to buy more allocation without sending AVAX too.
            user.allocation = requiredAllocation;
        }

        user.balance += msg.value;
        WAVAX.deposit{value: msg.value}();
        wavaxBalance += msg.value;

        if (rJoeNeeded > 0) {
            rJoe.burnFrom(msg.sender, rJoeNeeded);
        }
        emit UserParticipated(msg.sender, msg.value, rJoeNeeded);
    }

    /// @notice Withdraw AVAX, only permitted during phase 1 and 2
    /// @param _amount The amount of AVAX to withdraw
    function withdrawAVAX(uint256 _amount) public isStopped(false) {
        Phase _currentPhase = currentPhase();
        require(
            _currentPhase == Phase.PhaseOne || _currentPhase == Phase.PhaseTwo,
            "LaunchEvent: unable to withdraw"
        );
        require(_amount > 0, 'LaunchEvent: invalid withdraw amount');
        UserAllocation storage user = getUserAllocation[msg.sender];
        require(
            user.balance >= _amount,
            "LaunchEvent: withdrawn amount exceeds balance"
        );
        user.balance -= _amount;

        uint256 feeAmount = (_amount * getPenalty()) / 1e18;
        uint256 amountMinusFee = _amount - feeAmount;

        WAVAX.withdraw(_amount);

        wavaxBalance -= _amount;
        _safeTransferAVAX(msg.sender, amountMinusFee);

        if (feeAmount > 0) {
            _safeTransferAVAX(rocketJoeFactory.penaltyCollector(), feeAmount);
        }
    }

    /// @notice Create the JoePair
    /// @dev Can only be called once after phase 3 has started
    function createPair() external isStopped(false) atPhase(Phase.PhaseThree) {
        require(
            factory.getPair(address(WAVAX), address(token)) == address(0),
            "LaunchEvent: pair already created"
        );
        require(wavaxBalance > 0, 'LaunchEvent: no wavax balance');

        (address wavaxAddress, address tokenAddress) = (
            address(WAVAX),
            address(token)
        );

        uint256 tokenAllocated = tokenBalance;

        // Adjust the amount of tokens sent to the pool if floor price not met
        if (floorPrice > (wavaxBalance * 1e18) / tokenAllocated) {
            tokenAllocated = (wavaxBalance * 10**token.decimals()) / floorPrice;
        }

        WAVAX.approve(address(router), wavaxBalance);
        token.approve(address(router), tokenAllocated);

        /// We can't trust the output cause of reflect tokens
        (, , lpSupply) = router.addLiquidity(
            wavaxAddress, // tokenA
            tokenAddress, // tokenB
            wavaxBalance, // amountADesired
            tokenAllocated, // amountBDesired
            wavaxBalance, // amountAMin
            tokenAllocated, // amountBMin
            address(this), // to
            block.timestamp // deadline
        );

        pair = IJoePair(factory.getPair(tokenAddress, wavaxAddress));
        avaxAllocated = WAVAX.balanceOf(address(pair));
        wavaxBalance -= avaxAllocated;

        tokenReserve -= tokenAllocated;
        tokenBalance = tokenReserve;

        emit LiquidityPoolCreated(
            address(pair),
            pair.token0(),
            pair.token1(),
            wavaxBalance,
            tokenBalance
        );
    }

    /// @notice Withdraw liquidity pool tokens
    function withdrawLiquidity()
        external
        isStopped(false)
        atPhase(Phase.PhaseThree)
        timelockElapsed
    {
        require(
            address(pair) != address(0),
            "LaunchEvent: pair does not exist"
        );

        UserAllocation storage user = getUserAllocation[msg.sender];
        require(
            !user.hasWithdrawnPair,
            "LaunchEvent: liquidity already withdrawn"
        );
        user.hasWithdrawnPair = true;

        uint256 balance = pairBalance(msg.sender);

        if (msg.sender == issuer) {
            uint256 amountToWithdraw = lpSupply / 2;
            pair.transfer(issuer, amountToWithdraw);
            emit IssuerLiquidityWithdrawn(
                issuer,
                address(pair),
                amountToWithdraw
            );

            if (tokenReserve > 0) {
                uint256 amount = tokenReserve / 2;
                token.transfer(issuer, amount);
                tokenBalance -= amount;
            }
        } else {
            pair.transfer(msg.sender, balance);

            if (tokenReserve > 0) {
                uint256 amount = (user.allocation * tokenReserve) /
                    avaxAllocated /
                    2;
                token.transfer(msg.sender, amount);
                tokenBalance -= amount;
                emit UserLiquidityWithdrawn(msg.sender, address(pair), balance);
            }
        }
    }

    /// @notice Withdraw AVAX if launch has been cancelled
    function emergencyWithdraw() external isStopped(true) {
        if (msg.sender != issuer) {
            UserAllocation storage user = getUserAllocation[msg.sender];
            require(
                user.balance > 0,
                "LaunchEvent: expected user to have non-zero balance to perform emergency withdraw"
            );

            uint256 balance = user.balance;
            user.balance = 0;
            wavaxBalance -= balance;
            WAVAX.withdraw(balance);

            _safeTransferAVAX(msg.sender, balance);

            emit AvaxEmergencyWithdraw(msg.sender, balance);
        } else {
            uint256 balance = tokenBalance;
            tokenBalance = 0;
            token.transfer(issuer, balance);
            emit TokenEmergencyWithdraw(msg.sender, balance);
        }
    }

    /// @notice Stops the launch event and allows participants withdraw deposits
    function allowEmergencyWithdraw() external {
        require(
            msg.sender == Ownable(address(rocketJoeFactory)).owner(),
            "LaunchEvent: caller is not RocketJoeFactory owner"
        );
        stopped = true;
        emit Stopped();
    }

    /// @notice Force balances to match tokens that were deposited, but not sent directly to the contract.
    /// Any excess tokens are sent to the penaltyCollector
    function skim() external {
        address penaltyCollector = rocketJoeFactory.penaltyCollector();

        uint256 excessToken = token.balanceOf(address(this)) - tokenBalance;
        if (excessToken > 0) {
            token.transfer(
                penaltyCollector,
                token.balanceOf(address(this)) - tokenBalance
            );
        }

        uint256 excessWavax = WAVAX.balanceOf(address(this)) - wavaxBalance;
        if (excessWavax > 0) {
            WAVAX.transfer(penaltyCollector, excessWavax);
        }

        uint256 excessAvax = address(this).balance;
        if (excessAvax > 0) _safeTransferAVAX(penaltyCollector, excessAvax);
    }

    /// @notice Returns the current penalty for early withdrawal
    /// @return The penalty to apply to a withdrawal amount
    function getPenalty() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - auctionStart;
        if (timeElapsed < 1 days) {
            return 0;
        } else if (timeElapsed < PHASE_ONE_DURATION) {
            return
                ((timeElapsed - 1 days) * maxWithdrawPenalty) /
                uint256(PHASE_ONE_DURATION - 1 days);
        }
        return fixedWithdrawPenalty;
    }

    /// @notice Returns the current balance of the pool
    /// @return The balances of WAVAX and distribution token held by the launch contract
    function getReserves() public view returns (uint256, uint256) {
        return (wavaxBalance, tokenBalance);
    }

    /// @notice Get the rJOE amount needed to deposit AVAX
    /// @param _avaxAmount The amount of AVAX to deposit
    /// @return The amount of rJOE needed
    function getRJoeAmount(uint256 _avaxAmount) public view returns (uint256) {
        return _avaxAmount * rJoePerAvax;
    }

    /// @notice The total amount of liquidity pool tokens the user can withdraw
    /// @param _user The address of the user to check
    function pairBalance(address _user) public view returns (uint256) {
        if (avaxAllocated == 0 || getUserAllocation[_user].hasWithdrawnPair) {
            return 0;
        }
        return
            (getUserAllocation[_user].balance * lpSupply) / avaxAllocated / 2;
    }

    /// @dev bytecode size optimization for the `atPhase` modifier
    /// This works becuase internal functions are not in-lined in modifiers
    function _atPhase(Phase _phase) internal view {
        if (_phase == Phase.NotStarted) {
            require(
                currentPhase() == Phase.NotStarted,
                "LaunchEvent: not in not started"
            );
        } else if (_phase == Phase.PhaseOne) {
            require(
                currentPhase() == Phase.PhaseOne,
                "LaunchEvent: not in phase one"
            );
        } else if (_phase == Phase.PhaseTwo) {
            require(
                currentPhase() == Phase.PhaseTwo,
                "LaunchEvent: not in phase two"
            );
        } else if (_phase == Phase.PhaseThree) {
            require(
                currentPhase() == Phase.PhaseThree,
                "LaunchEvent: not in phase three"
            );
        } else {
            revert("LaunchEvent: unknown state");
        }
    }

    /// @notice Send AVAX
    /// @param _to The receiving address
    /// @param _value The amount of AVAX to send
    /// @dev Will revert on failure
    function _safeTransferAVAX(address _to, uint256 _value) internal {
        (bool success, ) = _to.call{value: _value}(new bytes(0));
        require(success, "LaunchEvent: avax transfer failed");
    }
}
