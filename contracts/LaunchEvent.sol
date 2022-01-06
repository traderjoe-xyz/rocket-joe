// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IWAVAX.sol";
import "./interfaces/IJoeRouter02.sol";
import "./interfaces/IJoeFactory.sol";
import "./interfaces/IJoePair.sol";
import "./interfaces/IRocketJoeFactory.sol";

import "./RocketJoeToken.sol";

/// @title Rocket Joe Launch Event
/// @author traderjoexyz
/// @notice A liquidity launch contract enabling price discover and token distribution as secondary market listing price.
/// TODO: - if token hasn't 18 decimals, it needs some changes
///       - Calculate AVAX:rJOE ratio.
///       - give owner to issuer ?
///       - emergency withdraws
contract LaunchEvent is Ownable {
    /// @notice Issuer of that contract.
    address private issuer;

    /// @notice The start time of phase 1.
    uint256 public phaseOne;

    /// @notice floor price (can be 0)
    uint256 public floorPrice;

    /// @notice When can user withdraw their LP (phase 3).
    uint256 private userTimelock;

    /// @notice When can issuer withdraw their LP (phase 3).
    uint256 private issuerTimelock;

    /// @notice The withdraw penalty gradient in “bps per sec”, in parts per 1e12 (phase 1).
    /// e.g. linearly reach 50% in 2 days `withdrawPenaltyGradient = 50 * 100 * 1e12 / 2 days`
    uint256 private withdrawPenaltyGradient;

    /// @notice The fixed withdraw penalty, in parts per 1e12 (phase 2).
    /// e.g. fixed penalty of 20% `fixedWithdrawPenalty = 20e11`
    uint256 private fixedWithdrawPenalty;

    /// @dev rJOE token contract.
    RocketJoeToken private rJoe;
    /// @dev RJoe needed to deposit 1 AVAX
    uint256 private rJoePerAvax;
    /// @dev WAVAX token contract.
    IWAVAX private WAVAX;
    /// @dev THE token contract.
    IERC20 public token;

    /// @dev Joe Router contract.
    IJoeRouter02 private router;
    /// @dev Joe Factory contract.
    IJoeFactory private factory;
    /// @dev Rocket Joe Factory contract.
    IRocketJoeFactory private rocketJoeFactory;

    /// @dev internal state variable for paused
    bool internal isStopped;

    /// @dev max and min allocation limits.
    uint256 public minAllocation;
    uint256 public maxAllocation;

    /// @dev struct used to record a users allocation and allocation used.
    struct UserAllocation {
        uint256 allocation;
        uint256 pairPoolWithdrawn;
    }
    /// @dev mapping of users to allocation record.
    mapping(address => UserAllocation) public users;

    /// @dev the address of the uniswap pair. Only set after createLiquidityPool is called.
    IJoePair private pair;

    /// @dev pool information
    uint256 private avaxAllocated;
    uint256 private tokenAllocated;
    uint256 private lpSupply;

    uint256 private tokenReserve;

    /// Constructor

    constructor() {
        rocketJoeFactory = IRocketJoeFactory(msg.sender);
        WAVAX = IWAVAX(rocketJoeFactory.wavax());
        router = IJoeRouter02(rocketJoeFactory.router());
        factory = IJoeFactory(rocketJoeFactory.factory());
        rJoe = RocketJoeToken(rocketJoeFactory.rJoe());
        rJoePerAvax = rocketJoeFactory.rJoePerAvax();
    }

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
        require(_issuer != address(0), "LaunchEvent: issuer is null address");
        require(_phaseOne >= block.timestamp, "LaunchEvent: phase1 starts in the past");
        require(_withdrawPenaltyGradient < 5e11 / uint256(2 days), "LaunchEvent: withdrawPenaltyGradient too big"); /// 50%
        require(_fixedWithdrawPenalty < 5e11, "LaunchEvent: fixedWithdrawPenalty too big"); /// 50%
        require(_maxAllocation >= _minAllocation, "LaunchEvent: max allocation less than min");
        require(_userTimelock < 7 days, "LaunchEvent: can't lock user LP for more than 7 days");
        require(_issuerTimelock > _userTimelock, "LaunchEvent: issuer can't withdraw before users");

        issuer = _issuer;
        transferOwnership(issuer);
        /// Different time phases
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

    /// Public functions.

    /// @notice Deposits AVAX and burns rJoe.
    /// @dev Checks are done in the `_depositWAVAX` function.
    function depositAVAX() external payable {
        require(!isStopped, "LaunchEvent: stopped");
        require(block.timestamp >= phaseOne && block.timestamp < (phaseOne + 3 days), "LaunchEvent: phase1 is over");
        WAVAX.deposit{value: msg.value}();
        _depositWAVAX(msg.sender, msg.value); // checks are done here.
    }

    /// @dev withdraw AVAX only during phase 1 and 2.
    function withdrawWAVAX(uint256 amount) public {
        require(!isStopped, "LaunchEvent: stopped");
        require(
            block.timestamp >= phaseOne && block.timestamp < (phaseOne + 4 days),
            "LaunchEvent: can't withdraw after phase2"
        );

        UserAllocation storage user = users[msg.sender];
        require(user.allocation >= amount, "LaunchEvent: withdrawn amount exceeds balance");
        user.allocation = user.allocation - amount;

        uint256 feeAmount = (amount * getPenalty()) / 1e12;
        uint256 amountMinusFee = amount - feeAmount;

        WAVAX.withdraw(amount);

        safeTransferAVAX(msg.sender, amountMinusFee);
        if (feeAmount > 0) {
            safeTransferAVAX(rocketJoeFactory.penaltyCollector(), feeAmount);
        }
    }

    /// @dev Needed for withdrawing from WAVAX contract.
    receive() external payable {
        require(msg.sender == address(WAVAX), "LaunchEvent: You can't send AVAX directly to this contract");
    }
    /// @dev Returns the current penalty
    function getPenalty() public view returns (uint256) {
        uint256 startedSince = block.timestamp - phaseOne;
        if (startedSince < 1 days) {
            return 0;
        } else if (startedSince < 3 days) {
            return (startedSince - 1 days) * withdrawPenaltyGradient;
        }
        return fixedWithdrawPenalty;
    }

    /// @dev Returns the current balance of the pool
    function poolInfo() public view returns (uint256, uint256) {
        return (IERC20(address(WAVAX)).balanceOf(address(this)), token.balanceOf(address(this)));
    }

    /// @dev Create the uniswap pair, can be called by anyone but only once
    /// @dev but only once after phase 3 has started.
    function createPair() external {
        require(!isStopped, "LaunchEvent: stopped");
        require(block.timestamp >= (phaseOne + 4 days), "LaunchEvent: not in phase three");
        require(factory.getPair(address(WAVAX), address(token)) == address(0), "LaunchEvent: pair already created");
        (address wavaxAddress, address tokenAddress) = (address(WAVAX), address(token));
        (uint256 avaxBalance, uint256 tokenBalance) = poolInfo();

        if (floorPrice > (avaxBalance * 1e18) / tokenBalance) {
            tokenBalance = (avaxBalance * 1e18) / floorPrice;
        }

        IERC20(wavaxAddress).approve(address(router), ~uint256(0));
        IERC20(tokenAddress).approve(address(router), ~uint256(0));

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

        tokenReserve = tokenReserve - tokenAllocated;
    }

    /// @dev withdraw the liquidity pool tokens.
    function withdrawLiquidity() external {
        require(!isStopped, "LaunchEvent: stopped");
        require(address(pair) != address(0), "LaunchEvent: pair is 0 address");
        require(
            block.timestamp > (phaseOne + 4 days) + userTimelock,
            "LaunchEvent: can't withdraw before user's timelock"
        );
        pair.transfer(msg.sender, pairBalance(msg.sender));

        if (tokenReserve > 0) {
            token.transfer(msg.sender, (users[msg.sender].allocation * tokenReserve) / avaxAllocated / 2);
        }

        if (msg.sender == issuer) {
            // TODO: require or simple check ?
            require(
                block.timestamp > (phaseOne + 4 days) + issuerTimelock,
                "LaunchEvent: can't withdraw before issuer's timelock"
            );

            pair.transfer(issuer, lpSupply / 2);

            if (tokenReserve > 0) {
                token.transfer(issuer, (tokenReserve * 1e18) / avaxAllocated / 2);
            }
        }
    }

    /// @dev get the rJoe amount needed;
    function getRJoeAmount(uint256 avaxAmount) public view returns (uint256) {
        return avaxAmount * rJoePerAvax;
    }

    /// @dev The total amount of liquidity pool tokens the user can withdraw.
    function pairBalance(address _user) public view returns (uint256) {
        if (avaxAllocated == 0) {
            return 0;
        }

        return (users[_user].allocation * lpSupply) / avaxAllocated / 2;
    }

    function emergencyWithdraw() external {
        require(isStopped, "Launch Event: is not stopped");

        UserAllocation storage user = users[msg.sender];

        safeTransferAVAX(msg.sender, user.allocation);

        user.allocation = 0;

        if (msg.sender == issuer) {
            token.transfer(issuer, token.balanceOf(issuer));
        }
    }

    /// Restricted functions.

    /// @dev Allows user and isssuer to emergency withdraw their funds
    function allowEmergencyWithdraw() external {
        require(
            msg.sender == Ownable(address(rocketJoeFactory)).owner(),
            "Launch Event: caller is not RJFactory owner"
        );
        isStopped = true;
    }

    /// Internal functions.

    /// @dev Transfers `value` AVAX to address.
    function safeTransferAVAX(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "LaunchEvent: avax transfer failed");
    }

    /// @notice Use your allocation credits by sending WAVAX.
    function _depositWAVAX(address from, uint256 avaxAmount) internal {
        require(!isStopped, "LaunchEvent: stopped");
        require(avaxAmount >= minAllocation, "LaunchEvent: amount doesnt fulfil min allocation");

        UserAllocation storage user = users[from];
        require(user.allocation + avaxAmount <= maxAllocation, "LaunchEvent: amount exceeds max allocation");

        uint256 rJoeAmount = getRJoeAmount(avaxAmount);
        rJoe.transferFrom(from, address(this), rJoeAmount);
        rJoe.burn(rJoeAmount);

        user.allocation = user.allocation + avaxAmount;
    }
}
