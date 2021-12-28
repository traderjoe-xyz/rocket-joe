// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}
interface IWAVAX {
    function balanceOf(address account) external returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external;
}


/// @title Rocket Joe Launch Event
/// @author traderjoexyz
/// @notice A liquidity launch contract enabling price discover and token distribution as secondary market listing price.
contract LaunchEvent {

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
    /// @notice The length in seconds of phase 3.
    uint256 public phaseThreeLengthSeconds;

    /// @notice The address where penalties are sent.
    address public penaltyCollection;

    /// @dev rJOE token contract.
    IERC20 public rJoe;
    /// @dev WAVAX token contract.
    IWAVAX public WAVAX;

    /// @dev internal state variable for paused
    bool internal isPaused;

    /// @dev max and min allocation limits.
    uint256 public minAllocation;
    uint256 public maxAllocation;

    /// @dev struct used to record a users allocation and allocation used.
    struct UserAllocation {
        uint256 totalAllocation;
        uint256 allocationUsed;
        uint256 pairPoolWithdrawn;
    }
    /// @dev mapping of users to allocation record.
    mapping(address => UserAllocation) public accounts;

    /// @dev the address of the uniswap pair. Only set after createLiquidityPool is called.
    address public pairAddress;

    //
    // Modifiers
    //

    modifier notPaused() {
        require(isPaused != true, "Contract is paused");
        _;
    }

    modifier phaseOneOnly() {
        require(
            block.timestamp >= phaseOneStartTime &&
            block.timestamp <= (phaseOneStartTime + phaseOneLengthSeconds),
            "Not in phase one"
        );
        _;
    }

    modifier phaseThreeOrLater() {
        require(
            block.timestamp >= phaseOneStartTime,
            "Not in phase three"
        );
        _;
    }

    modifier ended() {
        require(
            block.timestamp >= phaseThreeStartTime + phaseThreeLengthSeconds,
            "Launch has not ended"
        );
        _;
    }

    modifier pairNotCreated() {
        require(pairAddress == address(0), "Pair is not 0 address");
        _;
    }

    modifier pairCreated() {
        require(pairAddress != address(0), "Pair is 0 address");
        _;
    }


    //
    // Public functions.
    //

    /// @dev burn the deposited rJoe tokens.
    function buyAllocationCredits(uint256 rJoeAmount) public phaseOneOnly() notPaused() {
        burnRJoe(rJoeAmount);
        addAllocation(msg.sender, rJoeAmount);
    }

    /// @notice Use your allocation credits by sending WAVAX.
    function depositWAVAX(uint256 amount) public phaseOneOnly() notPaused() {
        uint256 currentBalance = WAVAX.balanceOf(address(this));
        WAVAX.transferFrom(msg.sender, address(this), amount);
        uint256 sent = WAVAX.balanceOf(address(this)) - currentBalance;
        useAllocation(msg.sender, sent);
    }

    /// @dev withdraw WAVAX only during phase 1 and 2.
    /// @dev TODO: penalty calculator.
    function withdrawWAVAX() public notPaused() {
        // User can only withdraw in phase 1 and 2
        // require user has deposited amount before.
        // reduce users allocationUsed, totalAllocation by amount.
        // send fee to penaltyAddress.
        // send Wavax to user.
    }

    /// @dev Create the uniswap pair, can be called by anyone
    /// @dev but only once after phase 3 has started.
    function createPair() public notPaused() phaseThreeOrLater() pairNotCreated() {

    }

    /// @dev withdraw the liquidity pool tokens.
    /// @dev TODO: Implement.
    function withdrawLiquidity() public ended() notPaused() ended() pairCreated() {

    }

    //
    // Internal functions.
    //

    /// @dev Transfers and burns all the rJoe.
    function burnRJoe(uint256 rJoeAmount) internal {
        require(rJoe.balanceOf(address(this)) == 0);
        rJoe.transferFrom(msg.sender, address(this), rJoeAmount);
        require(rJoe.balanceOf(address(this)) == rJoeAmount);
        rJoe.burn(address(this), rJoeAmount);
    }

    /// @dev get the allocation credits for this rjoe;
    /// @dev TODO: implement, currently just returns the allocation credits.
    function getAllocation(uint256 rJoeAmount) public pure returns (uint256) {
        return rJoeAmount;
    }

    /// @dev Adds to a users total allocation available.
    /// @dev reverts if the allocation added is above/below the max/min allocation.
    function addAllocation(address _account, uint256 rJoeAmount) internal {
        uint256 _allocation = getAllocation(rJoeAmount);
        UserAllocation storage account = accounts[_account];
        // Check the user is within max and min allocations.
        require(account.totalAllocation + _allocation >= minAllocation);
        require(account.totalAllocation + _allocation <= maxAllocation);
        account.totalAllocation = account.totalAllocation + _allocation;
    }

    /// @dev Uses an amount of allocation.
    /// @dev reverts if amount is above a users remaining limit.
    function useAllocation(address _account, uint256 amount) internal {
        require(amount <= getAccountAllocationRemaining(msg.sender), "Not enough allocation credit");
        UserAllocation storage account = accounts[_account];
        account.allocationUsed = account.allocationUsed + amount;
    }

    /// @dev returns the ammount of allocation an account can still use.
    function getAccountAllocationRemaining(address account) internal view returns (uint256) {
        return accounts[account].totalAllocation - accounts[account].allocationUsed;
    }

    /// @dev The total amount of liquidity pool tokens the user can withdraw.
    function pairBalance(address account) public view returns (uint256) {

    }

    function isPhaseOne() internal view returns (bool){
        require(
            block.timestamp >= phaseOneStartTime &&
            block.timestamp <= (phaseOneStartTime + phaseOneLengthSeconds),
            "Not in phase one"
        );
        return true;
    }

    function isPhaseTwo() internal view returns (bool){
        require(
            block.timestamp >= phaseTwoStartTime &&
            block.timestamp <= (phaseTwoStartTime + phaseTwoLengthSeconds),
            "Not in phase two"
        );
        return true;
    }

}
