// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        bool hasWithdrawnPair;
    }

    /// @notice Issuer of sale tokens
    address private issuer;

    /// @notice The start time of phase 1
    uint256 public auctionStart;

    uint256 public PHASE_ONE_DURATION;
    uint256 public PHASE_TWO_DURATION;

    /// @notice Floor price per AVAX (can be 0)
    uint256 public floorPrice;

    /// @notice Timelock duration post phase 3 when can user withdraw their LP tokens
    uint256 private userTimelock;

    /// @notice Timelock duration post phase 3 When can issuer withdraw their LP tokens
    uint256 public issuerTimelock;

    /// @notice The withdraw penalty gradient in bps per sec, in parts per 1e12 (phase 1)
    /// e.g. linearly reach 50% in 2 days `withdrawPenaltyGradient = 50 * 100 * 1e12 / 2 days`
    uint256 public withdrawPenaltyGradient;

    /// @notice The fixed withdraw penalty, in parts per 1e12 (phase 2)
    /// e.g. fixed penalty of 20% `fixedWithdrawPenalty = 20e11`
    uint256 public fixedWithdrawPenalty;

    IRocketJoeToken public rJoe;
    uint256 public rJoePerAvax;
    IWAVAX public WAVAX;
    IERC20 public token;

    IJoeRouter02 public router;
    IJoeFactory public factory;
    IRocketJoeFactory public rocketJoeFactory;

    bool internal initialized;
    bool internal isStopped;

    /// @dev max and min allocation limits in AVAX
    uint256 public minAllocation;
    uint256 public maxAllocation;

    mapping(address => UserAllocation) public getUserAllocation;

    /// @dev The address of the JoePair, set after createLiquidityPool is called
    IJoePair private pair;

    uint256 private avaxAllocated;
    uint256 private tokenAllocated;
    uint256 private lpSupply;

    uint256 private tokenReserve;

    event IssuingTokenDeposited(address token, uint amount);

    event UserParticipated(address user, uint AVAXamount, uint RJOEAmount);

    event UserWithdrawn(address user, uint AVAXamount);

    event LiquidityPoolCreated(address pair, address token0, address token1, uint amount0, uint amount1);

    event UserLiquidityWithdrawn(address user, address pair, uint amount);

    event IssuerLiquidityWithdrawn(address issuer, address pair, uint amount);

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
        _;
    }

    /// @notice Modifier which checks we are at a valid state in the auction for a user to withdraw their bid
    /// @dev This essentially checks we are in phase one or two
    modifier withdrawable() {
        require(
            currentPhase() == Phase.PhaseOne ||
                currentPhase() == Phase.PhaseTwo,
            "LaunchEvent: unable to withdraw"
        );
        _;
    }

    /// @notice Modifier which ensures the caller's timelock to withdraw has elapsed
    modifier timelockElapsed() {
        require(
            block.timestamp >
                auctionStart +
                    PHASE_ONE_DURATION +
                    PHASE_TWO_DURATION +
                    userTimelock,
            "LaunchEvent: can't withdraw before user's timelock"
        );
        if (msg.sender == issuer) {
            require(
                block.timestamp >
                    auctionStart +
                        PHASE_ONE_DURATION +
                        PHASE_TWO_DURATION +
                        issuerTimelock,
                "LaunchEvent: can't withdraw before issuer's timelock"
            );
        }
        _;
    }

    /// @notice Initialise the launch event with needed paramaters
    /// @param _issuer Address of the token issuer
    /// @param _auctionStart The start time of the auction
    /// @param _token The contract address of auctioned token
    /// @param _floorPrice The minimum price the token is sold at
    /// @param _minAllocation The minimum amount of AVAX depositable
    /// @param _maxAllocation The maximum amount of AVAX depositable
    /// @param _userTimelock The time a user must wait after auction ends to withdraw liquidity
    /// @param _issuerTimelock The time the issuer must wait after auction ends to withdraw liquidity
    /// @dev This function is called by the factory immediately after it creates the contract instance
    function initialize(
        address _issuer,
        uint256 _auctionStart,
        address _token,
        uint256 _floorPrice,
        uint256 _withdrawPenaltyGradient,
        uint256 _fixedWithdrawPenalty,
        uint256 _minAllocation,
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
            msg.sender == address(rocketJoeFactory),
            "LaunchEvent: forbidden"
        );
        require(
            _withdrawPenaltyGradient < 5e11 / uint256(2 days),
            "LaunchEvent: withdrawPenaltyGradient too big"
        ); // 50%
        require(
            _fixedWithdrawPenalty < 5e11,
            "LaunchEvent: fixedWithdrawPenalty too big"
        ); // 50%
        require(
            _maxAllocation >= _minAllocation,
            "LaunchEvent: max allocation less than min"
        );
        require(
            _userTimelock < 7 days,
            "LaunchEvent: can't lock user LP for more than 7 days"
        );
        require(
            _issuerTimelock > _userTimelock,
            "LaunchEvent: issuer can't withdraw before users"
        );
        require(
            _auctionStart > block.timestamp,
            "LaunchEvent: phase 1 has not started"
        );

        issuer = _issuer;

        auctionStart = _auctionStart;
        PHASE_ONE_DURATION = 3 days;
        PHASE_TWO_DURATION = 1 days;
        token = IERC20(_token);
        tokenReserve = token.balanceOf(address(this));
        floorPrice = _floorPrice;

        withdrawPenaltyGradient = _withdrawPenaltyGradient;
        fixedWithdrawPenalty = _fixedWithdrawPenalty;

        minAllocation = _minAllocation;
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
    function depositAVAX() external payable atPhase(Phase.PhaseOne) {
        require(!isStopped, "LaunchEvent: stopped");
        require(msg.sender != issuer, "LaunchEvent: issuer cannot participate");
        require(
            msg.value > 0,
            "LaunchEvent: expected non-zero AVAX to deposit"
        );
        require(
            msg.value >= minAllocation,
            "LaunchEvent: amount doesn't fulfill min allocation"
        );

        UserAllocation storage user = getUserAllocation[msg.sender];
        require(
            user.allocation + msg.value <= maxAllocation,
            "LaunchEvent: amount exceeds max allocation"
        );

        user.allocation += msg.value;
        user.hasWithdrawnPair = false;

        uint256 rJoeAmount = getRJoeAmount(msg.value);

        WAVAX.deposit{value: msg.value}();
        rJoe.transferFrom(msg.sender, address(this), rJoeAmount);
        rJoe.burn(rJoeAmount);
        emit UserParticipated(msg.sender, msg.value, rJoeAmount);
    }

    /// @notice Withdraw AVAX only during phase 1 and 2
    /// @param _amount The amount of AVAX to withdraw
    function withdrawAVAX(uint256 _amount) public withdrawable {
        require(!isStopped, "LaunchEvent: stopped");

        UserAllocation storage user = getUserAllocation[msg.sender];
        require(
            user.allocation >= _amount,
            "LaunchEvent: withdrawn amount exceeds balance"
        );
        user.allocation -= _amount;

        uint256 feeAmount = (_amount * getPenalty()) / 1e12;
        uint256 amountMinusFee = _amount - feeAmount;

        WAVAX.withdraw(_amount);

        _safeTransferAVAX(msg.sender, amountMinusFee);
        if (feeAmount > 0) {
            _safeTransferAVAX(rocketJoeFactory.penaltyCollector(), feeAmount);
        }
    }

    /// @notice Create the uniswap pair
    /// @dev Can only be called once after phase 3 has started
    function createPair() external atPhase(Phase.PhaseThree) {
        require(!isStopped, "LaunchEvent: stopped");
        require(
            factory.getPair(address(WAVAX), address(token)) == address(0),
            "LaunchEvent: pair already created"
        );

        (address wavaxAddress, address tokenAddress) = (
            address(WAVAX),
            address(token)
        );
        (uint256 avaxBalance, uint256 tokenBalance) = getReserves();

        // Adjust the amount of tokens sent to the pool if floor price not met
        if (floorPrice > (avaxBalance * 1e18) / tokenBalance) {
            tokenBalance = (avaxBalance * 1e18) / floorPrice;
        }

        WAVAX.approve(address(router), avaxBalance);
        token.approve(address(router), tokenBalance);

        /// We can't trust the output cause of reflect tokens
        (, , lpSupply) = router.addLiquidity(
            wavaxAddress, // tokenA
            tokenAddress, // tokenB
            avaxBalance, // amountADesired
            tokenBalance, // amountBDesired
            avaxBalance, // amountAMin
            tokenBalance, // amountBMin
            address(this), // to
            block.timestamp // deadline
        );

        pair = IJoePair(factory.getPair(tokenAddress, wavaxAddress));

        tokenAllocated = token.balanceOf(address(pair));
        avaxAllocated = IERC20(address(WAVAX)).balanceOf(address(pair));

        tokenReserve -= tokenAllocated;

        emit LiquidityPoolCreated(
            address(pair),
            pair.token0(),
            pair.token1(),
            avaxBalance,
            tokenBalance
        );
    }

    /// @notice Withdraw liquidity pool tokens
    function withdrawLiquidity() external timelockElapsed {
        require(!isStopped, "LaunchEvent: stopped");
        require(
            address(pair) != address(0),
            "LaunchEvent: pair does not exist"
        );

        UserAllocation storage user = getUserAllocation[msg.sender];
        require(!user.hasWithdrawnPair, "LaunchEvent: liquidity already withdrawn");
        user.hasWithdrawnPair = true;

        uint balance = pairBalance(msg.sender);
        pair.transfer(msg.sender, balance);
        emit UserLiquidityWithdrawn(msg.sender, address(pair), balance);

        if (tokenReserve > 0) {
            token.transfer(
                msg.sender,
                (user.allocation * tokenReserve) / avaxAllocated / 2
            );
        }

        UserAllocation storage user = getUserAllocation[msg.sender];
        require(
            !user.hasWithdrawnPair,
            "LaunchEvent: liquidity already withdrawn"
        );
        user.hasWithdrawnPair = true;

        if (msg.sender == issuer) {
            pair.transfer(issuer, lpSupply / 2);
            emit IssuerLiquidityWithdrawn(issuer, address(pair), lpSupply / 2);
            if (tokenReserve > 0) {
                token.transfer(issuer, tokenReserve / 2);
            }
        } else {
            pair.transfer(msg.sender, pairBalance(msg.sender));

            if (tokenReserve > 0) {
                token.transfer(
                    msg.sender,
                    (user.allocation * tokenReserve) / avaxAllocated / 2
                );
            }
        }
    }

    /// @notice Withdraw AVAX if launch has been cancelled
    function emergencyWithdraw() external {
        require(isStopped, "LaunchEvent: is still running");

        UserAllocation storage user = getUserAllocation[msg.sender];

        require(
            user.allocation > 0,
            "LaunchEvent: expected user to have non-zero allocation to perform emergency withdraw"
        );

        _safeTransferAVAX(msg.sender, user.allocation);

        user.allocation = 0;

        if (msg.sender == issuer) {
            token.transfer(issuer, token.balanceOf(issuer));
        }
    }

    /// @notice Stops the launch event and allows participants withdraw deposits
    function allowEmergencyWithdraw() external {
        require(
            msg.sender == Ownable(address(rocketJoeFactory)).owner(),
            "LaunchEvent: caller is not RocketJoeFactory owner"
        );
        isStopped = true;
    }

    /// @notice Returns the current penalty for early withdrawal
    /// @return The penalty to apply to a withdrawal amount
    function getPenalty() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - auctionStart;
        if (timeElapsed < 1 days) {
            return 0;
        } else if (timeElapsed < PHASE_ONE_DURATION) {
            return (timeElapsed - 1 days) * withdrawPenaltyGradient;
        }
        return fixedWithdrawPenalty;
    }

    /// @notice Returns the current balance of the pool
    /// @return The balances of WAVAX and distribution token held by the launch contract
    function getReserves() public view returns (uint256, uint256) {
        return (
            IERC20(address(WAVAX)).balanceOf(address(this)),
            token.balanceOf(address(this))
        );
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
            (getUserAllocation[_user].allocation * lpSupply) /
            avaxAllocated /
            2;
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
