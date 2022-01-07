// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IJoeFactory.sol";
import "./interfaces/IJoePair.sol";
import "./interfaces/IJoeRouter02.sol";
import "./interfaces/IRocketJoeFactory.sol";
import "./interfaces/IWAVAX.sol";

import "./RocketJoeToken.sol";

/// @title Rocket Joe Launch Event
/// @author Trader Joe
/// @notice A liquidity launch contract enabling price discovery and token distribution at secondary market listing price
contract LaunchEvent is Ownable {
    /// @notice Issuer of sale tokens
    address private issuer;

    /// @notice The start time of phase 1
    uint256 public phaseOne;

    uint256 private PHASE_ONE_DURATION = 3 days;
    uint256 private PHASE_TWO_DURATION = 1 days;

    /// @notice Floor price per AVAX (can be 0)
    uint256 public floorPrice;

    /// @notice Timelock duration post phase 3 when can user withdraw their LP tokens
    uint256 private userTimelock;

    /// @notice Timelock duration post phase 3 When can issuer withdraw their LP tokens
    uint256 private issuerTimelock;

    /// @notice The withdraw penalty gradient in bps per sec, in parts per 1e12 (phase 1)
    /// e.g. linearly reach 50% in 2 days `withdrawPenaltyGradient = 50 * 100 * 1e12 / 2 days`
    uint256 private withdrawPenaltyGradient;

    /// @notice The fixed withdraw penalty, in parts per 1e12 (phase 2)
    /// e.g. fixed penalty of 20% `fixedWithdrawPenalty = 20e11`
    uint256 private fixedWithdrawPenalty;

    RocketJoeToken private rJoe;
    uint256 private rJoePerAvax;
    IWAVAX immutable WAVAX;
    IERC20 public token;

    IJoeRouter02 private router;
    IJoeFactory private factory;
    IRocketJoeFactory private rocketJoeFactory;

    bool internal isStopped;

    uint256 public minAllocation;
    uint256 public maxAllocation;

    struct UserAllocation {
        uint256 allocation;
        bool pairPoolWithdrawn;
    }

    mapping(address => UserAllocation) public getUserAllocation;

    /// @dev The address of the Uniswap pair, set after createLiquidityPool is called
    IJoePair private pair;

    uint256 private avaxAllocated;
    uint256 private tokenAllocated;
    uint256 private lpSupply;

    uint256 private tokenReserve;

    /// @notice Creates the contract and sets the contracts it will interact with
    /// @dev Note: the launch event is not ready until the initialize function is called
    constructor() {
        rocketJoeFactory = IRocketJoeFactory(msg.sender);
        WAVAX = IWAVAX(rocketJoeFactory.wavax());
        router = IJoeRouter02(rocketJoeFactory.router());
        factory = IJoeFactory(rocketJoeFactory.factory());
        rJoe = RocketJoeToken(rocketJoeFactory.rJoe());
        rJoePerAvax = rocketJoeFactory.rJoePerAvax();
    }

    /// @notice Receive AVAX from the WAVAX contract
    /// @dev Needed for withdrawing from WAVAX contract.
    receive() external payable {
        require(
            msg.sender == address(WAVAX),
            "LaunchEvent: You can't send AVAX directly to this contract"
        );
    }

    /// @notice Initialise the launch event with needed paramaters
    /// @param _issuer Address of the token issuer
    /// @param _phaseOne The start time of the auction
    /// @param _token The contract address of auctioned token
    /// @param _floorPrice The minimum price the token is sold at
    /// @param _minAllocation The minimum amount of AVAX depositable
    /// @param _maxAllocation The maximum amount of AVAX depositable
    /// @param _userTimelock The time a user must wait after auction ends to withdraw liquidity
    /// @param _issuerTimelock The time the issuer must wait after auction ends to withdraw liquidity
    /// @dev This function is called by the factory immediately after it creates the contract instance
    function initialize(
        address _issuer,
        uint256 _phaseOne,
        address _token,
        uint256 _floorPrice,
        uint256 _withdrawPenaltyGradient,
        uint256 _fixedWithdrawPenalty,
        uint256 _minAllocation,
        uint256 _maxAllocation,
        uint256 _userTimelock,
        uint256 _issuerTimelock
    ) external {
        require(msg.sender == address(rocketJoeFactory), "LaunchEvent: forbidden");
        require(_phaseOne >= block.timestamp, "LaunchEvent: phase 1 has not started yet");
        require(
            _withdrawPenaltyGradient < 5e11 / uint256(2 days),
            "LaunchEvent: withdrawPenaltyGradient too big"
        ); /// 50%
        require(_fixedWithdrawPenalty < 5e11, "LaunchEvent: fixedWithdrawPenalty too big"); /// 50%
        require(_maxAllocation >= _minAllocation, "LaunchEvent: max allocation less than min");
        require(_userTimelock < 7 days, "LaunchEvent: can't lock user LP for more than 7 days");
        require(
            _issuerTimelock > _userTimelock,
            "LaunchEvent: issuer can't withdraw before users"
        );

        issuer = _issuer;
        transferOwnership(issuer);

        phaseOne = _phaseOne;

        token = IERC20(_token);
        tokenReserve = token.balanceOf(address(this));
        floorPrice = _floorPrice;

        withdrawPenaltyGradient = _withdrawPenaltyGradient;
        fixedWithdrawPenalty = _fixedWithdrawPenalty;

        minAllocation = _minAllocation;
        maxAllocation = _maxAllocation;

        userTimelock = _userTimelock;
        issuerTimelock = _issuerTimelock;
    }

    /// @notice Deposits AVAX and burns rJoe
    /// @dev Checks are done in the `_depositWAVAX` function
    function depositAVAX() external payable {
        require(!isStopped, "LaunchEvent: stopped");
        require(
            block.timestamp >= phaseOne && block.timestamp < (phaseOne + PHASE_ONE_DURATION),
            "LaunchEvent: phase 1 is over"
        );
        WAVAX.deposit{value: msg.value}();
        _depositWAVAX(msg.sender, msg.value); // checks are done here
    }

    /// @notice Create the uniswap pair
    /// @dev Can only be called once after phase 3 has started
    function createPair() external {
        require(!isStopped, "LaunchEvent: stopped");
        require(
            block.timestamp >= (phaseOne + PHASE_ONE_DURATION + PHASE_TWO_DURATION),
            "LaunchEvent: not in phase three");
        require(
            factory.getPair(address(WAVAX), address(token)) == address(0),
            "LaunchEvent: pair already created");
        (address wavaxAddress, address tokenAddress) = (address(WAVAX), address(token));
        (uint256 avaxBalance, uint256 tokenBalance) = getReserves();

        // Adjust the amount of tokens sent to the pool if floor price not met.
        if (floorPrice > (avaxBalance * 1e18) / tokenBalance) {
            tokenBalance = (avaxBalance * 1e18) / floorPrice;
        }

        IERC20(wavaxAddress).approve(address(router), avaxBalance);
        IERC20(tokenAddress).approve(address(router), tokenBalance);

        /// We can't trust the output cause of reflect tokens
        (, , lpSupply) = router.addLiquidity(
            tokenAddress,
            wavaxAddress,
            avaxBalance,
            tokenBalance,
            avaxBalance,
            tokenBalance,
            address(this),
            block.timestamp
        );

        pair = IJoePair(factory.getPair(tokenAddress, wavaxAddress));

        tokenAllocated = token.balanceOf(address(pair));
        avaxAllocated = IERC20(address(WAVAX)).balanceOf(address(pair));

        tokenReserve -= tokenAllocated;
    }

    /// @notice Withdraw liquidity pool tokens
    function withdrawLiquidity() external {
        require(!isStopped, "LaunchEvent: stopped");
        require(address(pair) != address(0), "LaunchEvent: pair does not exist");
        require(
            block.timestamp > phaseOne + PHASE_ONE_DURATION + PHASE_TWO_DURATION + userTimelock,
            "LaunchEvent: can't withdraw before user's timelock"
        );
        pair.transfer(msg.sender, pairBalance(msg.sender));

        if (tokenReserve > 0) {
            UserAllocation storage user = getUserAllocation[msg.sender];
            require(user.pairPoolWithdrawn == false, "LaunchEvent: liquidity already withdrawn");
            user.pairPoolWithdrawn = true;
            token.transfer(
                msg.sender,
                (user.allocation * tokenReserve) / avaxAllocated / 2
            );
        }

        if (msg.sender == issuer) {
            // TODO: require or simple check ?
            require(
                block.timestamp > phaseOne + PHASE_ONE_DURATION + PHASE_TWO_DURATION + issuerTimelock,
                "LaunchEvent: can't withdraw before issuer's timelock"
            );

            pair.transfer(issuer, lpSupply / 2);

            if (tokenReserve > 0) {
                token.transfer(issuer, (tokenReserve * 1e18) / avaxAllocated / 2);
            }
        }
    }

    /// @notice Withdraw AVAX if launch has been cancelled
    function emergencyWithdraw() external {
        require(isStopped, "Launch Event: is still running");

        UserAllocation storage user = getUserAllocation[msg.sender];

        safeTransferAVAX(msg.sender, user.allocation);

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
        uint256 timeElapsed = block.timestamp - phaseOne;
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
        return (IERC20(address(WAVAX)).balanceOf(address(this)), token.balanceOf(address(this)));
    }

    /// @notice Get the rJOE amount needed to deposit AVAX
    /// @param avaxAmount The amount of AVAX to deposit
    /// @return The amount of rJOE needed
    function getRJoeAmount(uint256 avaxAmount) public view returns (uint256) {
        return avaxAmount * rJoePerAvax;
    }

    /// @notice The total amount of liquidity pool tokens the user can withdraw
    /// @param _user The address of the user to check
    function pairBalance(address _user) public view returns (uint256) {
        if (avaxAllocated == 0 || getUserAllocation[_user].pairPoolWithdrawn == true) {
            return 0;
        }
        return (getUserAllocation[_user].allocation * lpSupply) / avaxAllocated / 2;
    }

    /// @notice Withdraw AVAX only during phase 1 and 2
    /// @param amount The amount of AVAX to withdraw
    function withdrawWAVAX(uint256 amount) public {
        require(!isStopped, "LaunchEvent: stopped");
        require(
            block.timestamp >= phaseOne &&
                block.timestamp < (phaseOne + PHASE_ONE_DURATION + PHASE_TWO_DURATION),
            "LaunchEvent: can't withdraw after phase2"
        );

        UserAllocation storage user = getUserAllocation[msg.sender];
        require(user.allocation >= amount, "LaunchEvent: withdrawn amount exceeds balance");
        user.allocation -= amount;

        uint256 feeAmount = (amount * getPenalty()) / 1e12;
        uint256 amountMinusFee = amount - feeAmount;

        WAVAX.withdraw(amount);

        safeTransferAVAX(msg.sender, amountMinusFee);
        if (feeAmount > 0) {
            safeTransferAVAX(rocketJoeFactory.penaltyCollector(), feeAmount);
        }
    }

    /// @notice Send AVAX
    /// @param to The receiving address
    /// @param value The amount of AVAX to send
    function safeTransferAVAX(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "LaunchEvent: avax transfer failed");
    }

    /// @notice Deposit WAVAX to participate in auction
    /// @param from The account deposit is allocated to
    /// @param avaxAmount The amount of AVAX deposited
    function _depositWAVAX(address from, uint256 avaxAmount) internal {
        require(!isStopped, "LaunchEvent: stopped");
        require(avaxAmount >= minAllocation, "LaunchEvent: amount doesn't fulfil min allocation");

        UserAllocation storage user = getUserAllocation[from];
        require(
            user.allocation + avaxAmount <= maxAllocation,
            "LaunchEvent: amount exceeds max allocation");

        user.allocation = user.allocation + avaxAmount;
        user.pairPoolWithdrawn = false;

        uint256 rJoeAmount = getRJoeAmount(avaxAmount);
        rJoe.transferFrom(from, address(this), rJoeAmount);
        rJoe.burn(rJoeAmount);
    }
}
