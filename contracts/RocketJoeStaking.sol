// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./RocketJoeToken.sol";

/// @title Rocket Joe Staking
/// @author traderjoexyz
/// @notice Stake joe to earn rJoe
contract RocketJoeStaking is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct UserInfo {
        uint256 amount; // How many joe tokens the user has provided
        uint256 rewardDebt; // Reward debt. See explanation below
        //
        // We do some fancy math here. Basically, any point in time, the amount of JOEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * accRJoePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. `accRJoePerShare` (and `lastRewardTimestamp`) gets updated
        //   2. User receives the pending reward sent to his/her address
        //   3. User's `amount` gets updated
        //   4. User's `rewardDebt` gets updated
    }

    IERC20Upgradeable public joe;
    uint256 public lastRewardTimestamp;
    /// @dev Accumulated rJoe per share, times PRECISION. See above
    uint256 public accRJoePerShare;

    uint256 private PRECISION;

    RocketJoeToken public rJoe;
    uint256 public rJoePerSec;

    /// @dev Info of each user that stakes LP tokens
    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event UpdateEmissionRate(address indexed user, uint256 _rJoePerSec);

    /// @notice Initialise with needed parameters
    /// @param _joe address of the joe token contract
    /// @param _rJoe address of the rJoe token contract
    /// @param _rJoePerSec number of rJoe tokens created per second
    function initialize(
        IERC20Upgradeable _joe,
        RocketJoeToken _rJoe,
        uint256 _rJoePerSec
    ) public initializer {
        __Ownable_init();

        PRECISION = 1e12;
        
        joe = _joe;
        rJoe = _rJoe;
        rJoePerSec = _rJoePerSec;
    }

    /// @notice Get pending rJoe for a given `_user`
    /// @param _user the user to lookup
    /// @return the number of pending rJoe tokens for `_user`
    function pendingRJoe(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 joeSupply = joe.balanceOf(address(this));
        uint256 _accRJoePerShare = accRJoePerShare;

        if (block.timestamp > lastRewardTimestamp && joeSupply != 0) {
            uint256 multiplier = block.timestamp - lastRewardTimestamp;
            uint256 rJoeReward = multiplier * rJoePerSec;
            _accRJoePerShare += (rJoeReward * PRECISION) / joeSupply;
        }
        return (user.amount * _accRJoePerShare) / PRECISION - user.rewardDebt;
    }

    /// @notice Deposit joe to RocketJoeStaking for rJoe allocation
    /// @param _amount amount of joe to deposit
    function deposit(uint256 _amount) external {
        UserInfo storage user = userInfo[msg.sender];

        updatePool();

        if (user.amount > 0) {
            uint256 pending = (user.amount * accRJoePerShare) / PRECISION - user.rewardDebt;
            safeRJoeTransfer(msg.sender, pending);
        }
        user.amount = user.amount + _amount;
        user.rewardDebt = (user.amount * accRJoePerShare) / PRECISION;

        joe.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit Deposit(msg.sender, _amount);
    }

    /// @notice Withdraw joe and accumulated rJoe from RocketJoeStaking
    /// @param _amount amount of joe to withdraw
    function withdraw(uint256 _amount) external {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool();

        uint256 pending = (user.amount * accRJoePerShare) / PRECISION - user.rewardDebt;
        
        user.amount = user.amount - _amount;
        user.rewardDebt = (user.amount * accRJoePerShare) / PRECISION;

        safeRJoeTransfer(msg.sender, pending);
        joe.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _amount);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY
    function emergencyWithdraw() external {
        UserInfo storage user = userInfo[msg.sender];

        uint256 _amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        joe.safeTransfer(address(msg.sender), _amount);
        emit EmergencyWithdraw(msg.sender, _amount);
    }

    /// @notice Update reward variables of the given pool with latest data
    function updatePool() public {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }
        uint256 joeSupply = joe.balanceOf(address(this));
        if (joeSupply == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 multiplier = block.timestamp - lastRewardTimestamp;
        uint256 rJoeReward = multiplier * rJoePerSec;
        accRJoePerShare = accRJoePerShare + (rJoeReward * PRECISION) / joeSupply;
        lastRewardTimestamp = block.timestamp;

        rJoe.mint(address(this), rJoeReward);
    }

    /// @notice Update reward variables of the given pool with latest data
    /// @param _rJoePerSec the new value for rJoePerSec
    function updateEmissionRate(uint256 _rJoePerSec) public onlyOwner {
        updatePool();
        rJoePerSec = _rJoePerSec;
        emit UpdateEmissionRate(msg.sender, _rJoePerSec);
    }

    /// @notice Safe rJoe transfer function, just in case if rounding error causes pool to not have enough JOEs
    /// @param _to address that wil receive rJoe
    /// @param _amount the amount to send
    function safeRJoeTransfer(address _to, uint256 _amount) internal {
        uint256 rJoeBal = rJoe.balanceOf(address(this));
        if (_amount > rJoeBal) {
            rJoe.transfer(_to, rJoeBal);
        } else {
            rJoe.transfer(_to, _amount);
        }
    }
}
