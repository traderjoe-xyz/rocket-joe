// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/IWAVAX.sol";
import "./interface/IJoeRouter02.sol";
import "./interface/IJoeFactory.sol";
import "./interface/IJoePair.sol";
import "./interface/IRocketJoeFactory.sol";

import "./RocketJoeToken.sol";


/// @title Rocket Joe Launch Event
/// @author traderjoexyz
/// @notice A liquidity launch contract enabling price discover and token distribution as secondary market listing price.
// TODO: - if token hasn't 18 decimals, it needs some changes
//       - Calculate AVAX:rJOE ratio.
//       - FInd a way to get rJoe address and penaltyCollector address.
//       - give owner to issuer ?
contract LaunchEvent is Ownable{

    /// @notice Issuer of that contract.
    address public issuer;

    /// @notice The start time of phase 1.
    uint256 public phaseOneStartTime;
    /// @notice The length in seconds of phase 1.
    uint256 public phaseOneLengthSeconds;

    /// @notice The start time of phase 2.
    uint256 public phaseTwoStartTime;
    /// @notice The length in seconds of phase 2.
    uint256 public phaseTwoLengthSeconds;

    /// @notice The start time of phase 3.
    uint256 public phaseThreeStartTime;

    /// @notice floor price (can be 0)
    uint256 public floorPrice;

    /// @notice When can user withdraw their LP (phase 3).
    uint256 public userTimelock;

    /// @notice When can issuer withdraw their LP (phase 3).
    uint256 public issuerTimelock;

    /// @notice The withdraw penalty gradient in “bps per sec”, in parts per 1e12 (phase 1).
    /// e.g. linearly reach 50% in 2 days `withdrawPenatlyGradient = 50 * 100 * 1e12 / 2 days`
    uint256 public withdrawPenatlyGradient;

    /// @notice The fixed withdraw penalty, in parts per 1e12 (phase 2).
    /// e.g. fixed penalty of 20% `fixedWithdrawPenalty = 20e11`
    uint256 public fixedWithdrawPenalty;

    /// @notice The address where penalties are sent.
    address public penaltyCollector;

    /// @dev rJOE token contract.
    RocketJoeToken public rJoe;
    /// @dev WAVAX token contract.
    IWAVAX public WAVAX;
    /// @dev THE token contract.
    IERC20 public token;

    /// @dev Joe Router contract.
    IJoeRouter02 router;
    /// @dev Joe Factory contract.
    IJoeFactory factory;
    /// @dev Rocket Joe Factory contract.
    IRocketJoeFactory rocketJoeFactory;

    /// @dev internal state variable for paused
    bool internal isPaused;

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
    IJoePair public pair;

    /// @dev pool information
    uint256 public avaxAllocated;
    uint256 public tokenAllocated;
    uint256 public lpSupply;

    uint256 public tokenReserve;

    //
    // Constructor
    //

    constructor() {
        rocketJoeFactory = IRocketJoeFactory(msg.sender);
        WAVAX = IWAVAX(rocketJoeFactory.wavax());
        router = IJoeRouter02(rocketJoeFactory.router());
        factory = IJoeFactory(rocketJoeFactory.factory());
        rJoe = RocketJoeToken(rocketJoeFactory.rJoe());
        penaltyCollector = rocketJoeFactory.penaltyCollector();
    }

    function initialize(
        address _issuer,
        uint256 _phaseOneStartTime,
        address _token,
        uint256 _floorPrice,
        uint256 _withdrawPenatlyGradient,
        uint256 _fixedWithdrawPenalty,
        uint256 _minAllocation,
        uint256 _maxAllocation,
        uint256 _userTimelock,
        uint256 _issuerTimelock
    ) external {
        require(msg.sender == address(rocketJoeFactory), "LaunchEvent; Forbidden");
        require(_issuer != address(0), "LaunchEvent: Issuer can't be null address");
        require(_phaseOneStartTime >= block.timestamp, "LaunchEvent: Phase 1 needs to start after the current timestamp");
        require(factory.getPair(address(WAVAX), address(token)) == address(0), "LaunchEvent: Pair already exists");
        require(_withdrawPenatlyGradient < 5e11 / uint256(2 days), "LaunchEvent: withdrawPenatlyGradient too big"); // 50%
        require(_fixedWithdrawPenalty < 5e11, "LaunchEvent: fixedWithdrawPenalty too big"); // 50%
        require(_maxAllocation >= _minAllocation, "LaunchEvent: Max allocation needs to be greater than min's one");
        require(_userTimelock < 7 days, "LaunchEvent: Can't lock user LP for more than 7 days");
        require(_issuerTimelock > _userTimelock, "LaunchEvent: Issuer can't withdraw their LP before everyone");

        issuer = _issuer;

        // Different time phases
        phaseOneStartTime = _phaseOneStartTime;
        phaseOneLengthSeconds = 3 days;
        phaseTwoStartTime = _phaseOneStartTime + phaseOneLengthSeconds + 1;
        phaseTwoLengthSeconds = 1 days;
        phaseThreeStartTime = phaseTwoStartTime + phaseTwoLengthSeconds + 1;

        require(block.timestamp + _userTimelock > phaseThreeStartTime, "LaunchEvent: Unlocks can't happen before the start of Phase 3");

        token = IERC20(_token);
        tokenReserve = token.balanceOf(address(this));
        floorPrice = _floorPrice;

        withdrawPenatlyGradient = _withdrawPenatlyGradient;
        fixedWithdrawPenalty = _fixedWithdrawPenalty;

        minAllocation = _minAllocation;
        maxAllocation = _maxAllocation;

        userTimelock = _userTimelock;
        issuerTimelock = _issuerTimelock;
    }

    //
    // Modifiers
    //

    modifier notPaused() {
        require(isPaused != true, "LaunchEvent: Contract is paused");
        _;
    }

    modifier phaseOneOnly() {
        require(
            block.timestamp >= phaseOneStartTime &&
            block.timestamp <= (phaseOneStartTime + phaseOneLengthSeconds),
            "LaunchEvent: Not in phase one"
        );
        _;
    }

    modifier phaseThreeOrLater() {
        require(
            block.timestamp >= phaseThreeStartTime,
            "LaunchEvent: Not in phase three"
        );
        _;
    }

    modifier pairNotCreated() {
        require(address(pair) == address(0), "LaunchEvent: Pair is not 0 address");
        _;
    }

    modifier pairCreated() {
        require(address(pair) != address(0), "LaunchEvent: Pair is 0 address");
        _;
    }


    //
    // Public functions.
    //

    /// @notice Deposits AVAX and burns rJoe.
    function depositAVAX() external payable phaseOneOnly notPaused {
        WAVAX.deposit{value: msg.value}();
        _depositWAVAX(msg.sender, msg.value); // checks are done here.
    }

    /// @notice Deposits WAVAX and burns rJoe.
    function depositWAVAX(uint256 amount) external phaseOneOnly notPaused {
        IERC20(address(WAVAX)).transferFrom(msg.sender, address(this), amount);
        _depositWAVAX(msg.sender, amount); // checks are done here.
    }

    /// @dev withdraw AVAX only during phase 1 and 2.
    function withdrawWAVAX(uint256 amount) public notPaused {
        require(isPhaseOne() || isPhaseTwo(), "LaunchEvent: Can't withdraw after phase 2.");

        UserAllocation storage user = users[msg.sender];
        require(user.allocation >= amount, "LaunchEvent: Can't withdraw more than what you deposited");
        user.allocation = user.allocation - amount;

        uint256 feeAmount = amount * getPenalty() / 1e12;
        uint256 amountMinusFee = amount - feeAmount;

        WAVAX.withdraw(amount);

        safeTransferAVAX(msg.sender, amountMinusFee);
        safeTransferAVAX(penaltyCollector, feeAmount);
    }

    /// @dev Returns the current penalty
    function getPenalty() public view returns(uint256){
        uint256 startedSince = block.timestamp - phaseOneStartTime;
        if (startedSince < 1 days) {
            return 0;
        } else if (startedSince < 3 days) {
            return (startedSince - 1 days) * withdrawPenatlyGradient;
        } else {
            return fixedWithdrawPenalty;
        }
    }

    /// @dev Returns the current balance of the pool
    function poolInfo() public view returns(uint256, uint256){
        return (IERC20(address(WAVAX)).balanceOf(address(this)), token.balanceOf(address(this)));
    }

    /// @dev Create the uniswap pair, can be called by anyone but only once
    /// @dev but only once after phase 3 has started.
    function createPair() public notPaused phaseThreeOrLater pairNotCreated {
        (address wavaxAddress, address tokenAddress) = (address(WAVAX), address(token));
        (uint256 avaxBalance, uint256 tokenBalance) = poolInfo();

        if (floorPrice > avaxBalance * 1e18 / tokenBalance) {
            tokenBalance = avaxBalance * 1e18 / floorPrice;
        }

        IERC20(wavaxAddress).approve(address(router), ~uint256(0));
        IERC20(tokenAddress).approve(address(router), ~uint256(0));

        (tokenAllocated, avaxAllocated, lpSupply) = router.addLiquidity(
            wavaxAddress,
            tokenAddress,
            avaxBalance,
            tokenBalance,
            avaxBalance,
            tokenBalance,
            address(this),
            block.timestamp
        );
        if (wavaxAddress > tokenAddress) {
            pair = IJoePair(factory.getPair(tokenAddress, wavaxAddress));
        } else {
            pair = IJoePair(factory.getPair(wavaxAddress, tokenAddress));
            (tokenAllocated, avaxAllocated) = (avaxAllocated, tokenAllocated);
        }

        tokenReserve = tokenReserve - tokenAllocated;
    }

    /// @dev withdraw the liquidity pool tokens.
    function withdrawLiquidity() public notPaused pairCreated {
        require(block.timestamp > userTimelock, "LaunchEvent: Can't withdraw before user timelock");
        address to = msg.sender;
        pair.transfer(to, pairBalance(to));

        if (tokenReserve > 0) {
            UserAllocation memory user = users[msg.sender];
            token.transfer(msg.sender, user.allocation * tokenReserve / avaxAllocated / 2);
        }
    }

    /// @dev withdraw the liquidity pool tokens.
    function withdrawIssuerLiquidity() public notPaused pairCreated {
        require(msg.sender == issuer, "LaunchEvent: Caller is not Issuer");
        require(block.timestamp > issuerTimelock, "LaunchEvent: Can't withdraw before issuer timelock");

        pair.transfer(issuer, avaxAllocated / 2);

        if (tokenReserve > 0) {
            token.transfer(issuer, tokenReserve * 1e18 / avaxAllocated / 2);
        }
    }


    /// @dev get the allocation credits for this rjoe;
    /// @dev TODO: implement, currently just returns the allocation credits.
    function getAllocation(uint256 rJoeAmount) public pure returns (uint256) {
        return rJoeAmount;
    }

    /// @dev The total amount of liquidity pool tokens the user can withdraw.
    function pairBalance(address _user) public view returns (uint256) {
        if (avaxAllocated == 0) {
            return 0;
        }

        UserAllocation memory user = users[_user];

        return user.allocation * lpSupply / avaxAllocated / 2;
    }

    //
    // Restricted functions.
    //

    /// @dev Pause this contract
    function pause() public onlyOwner{
        isPaused = true;
    }

    /// @dev Unpause this contract
    function unpause() public onlyOwner{
        isPaused = false;
    }

    //
    // Internal functions.
    //

    /// @dev Transfers `value` AVAX to address.
    function safeTransferAVAX(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper: AVAX_TRANSFER_FAILED");
    }

    /// @dev Transfers and burns all the rJoe.
    function burnRJoe(address from, uint256 rJoeAmount) internal {
        rJoe.transferFrom(from, address(this), rJoeAmount);
        rJoe.burn(rJoeAmount);
    }

    /// @notice Use your allocation credits by sending WAVAX.
    function _depositWAVAX(address from, uint256 amount) internal phaseOneOnly notPaused {
        require(msg.value >= minAllocation, "LaunchEvent: Not enough AVAX sent to meet the min allocation");

        UserAllocation storage user = users[from];
        require(user.allocation + amount <= maxAllocation, "LaunchEvent: Too much AVAX sent to meet the max allocation");

        burnRJoe(from, amount); // TODO: AVAX:Rjoe ratio won't always be 1. But I don't get how it's calculated as floor price can be set to 0.

        user.allocation = user.allocation + amount;
    }

    function isPhaseOne() internal view returns (bool){
        require(
            block.timestamp >= phaseOneStartTime &&
            block.timestamp <= (phaseOneStartTime + phaseOneLengthSeconds),
            "LaunchEvent: Not in phase one"
        );
        return true;
    }

    function isPhaseTwo() internal view returns (bool){
        require(
            block.timestamp >= phaseTwoStartTime &&
            block.timestamp <= (phaseTwoStartTime + phaseTwoLengthSeconds),
            "LaunchEvent: Not in phase two"
        );
        return true;
    }

}
