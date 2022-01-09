// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./RocketJoeToken.sol";

/// @title Rocket Joe Staking
/// @author traderjoexyz
/// @notice Stake moJOE to earn rJOE
contract RocketJoeStaking is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct UserInfo {
        uint256 amount; // How many moJOE tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of JOEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * accRJoePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. `accRJoePerShare` (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    IERC20Upgradeable moJOE;
    uint256 lastRewardTimestamp;
    /// @dev Accumulated JOEs per share, times 1e12. See below
    uint256 accRJoePerShare;

    RocketJoeToken public rJOE;
    uint256 public rJoePerSec;

    /// @dev Info of each user that stakes LP tokens
    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event UpdateEmissionRate(address indexed user, uint256 _rJoePerSec);

    /// @notice Initialise with needed paramaters
    /// @param _moJOE address of the moJOE token contract
    /// @param _rJOE address of the rJOE token contract
    /// @param _rJoePerSec number of rJOE tokens created per second
    function initialize(
        IERC20Upgradeable _moJOE,
        RocketJoeToken _rJOE,
        uint256 _rJoePerSec
    ) public initializer {
        __Ownable_init();

        moJOE = _moJOE;
        rJOE = _rJOE;
        rJoePerSec = _rJoePerSec;
    }

    /// @notice Get pending rJOE for a given `_user`
    /// @param _user the user to lookup
    /// @return the number of pending rJOE tokens for `_user`
    function pendingRJoe(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 moJoeSupply = moJOE.balanceOf(address(this));
        uint256 _accRJoePerShare = accRJoePerShare;

        if (block.timestamp > lastRewardTimestamp && moJoeSupply != 0) {
            uint256 multiplier = block.timestamp - lastRewardTimestamp;
            uint256 rJoeReward = multiplier * rJoePerSec;
            _accRJoePerShare = _accRJoePerShare + (rJoeReward * 1e12) / moJoeSupply;
        }
        return (user.amount * _accRJoePerShare) / 1e12 - user.rewardDebt;
    }

    /// @notice Update reward variables of the given pool with latest data
    function updatePool() public {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }
        uint256 moJoeSupply = moJOE.balanceOf(address(this));
        if (moJoeSupply == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 multiplier = block.timestamp - lastRewardTimestamp;
        uint256 rJoeReward = multiplier * rJoePerSec;
        accRJoePerShare = accRJoePerShare + (rJoeReward * 1e12) / moJoeSupply;
        lastRewardTimestamp = block.timestamp;

        rJOE.mint(address(this), rJoeReward);
    }

    /// @notice Deposit moJOE to RocketJoeStaking for rJOE allocation
    /// @param _amount amount of moJOE to deposit
    function deposit(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];

        updatePool();
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRJoePerShare) / 1e12 - user.rewardDebt;
            safeRJoeTransfer(msg.sender, pending);
        }
        user.amount = user.amount + _amount;
        user.rewardDebt = (user.amount * accRJoePerShare) / 1e12;

        moJOE.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit Deposit(msg.sender, _amount);
    }

    /// @notice Withdraw moJOE and accumulated rJOE from RocketJoeStaking
    /// @param _amount amount of moJOE to withdraw
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool();
        uint256 pending = (user.amount * accRJoePerShare) / 1e12 - user.rewardDebt;
        user.amount = user.amount - _amount;
        user.rewardDebt = (user.amount * accRJoePerShare) / 1e12;

        safeRJoeTransfer(msg.sender, pending);
        moJOE.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        UserInfo storage user = userInfo[msg.sender];

        uint256 _amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        moJOE.safeTransfer(address(msg.sender), _amount);
        emit EmergencyWithdraw(msg.sender, _amount);
    }

    // Safe rJoe transfer function, just in case if rounding error causes pool to not have enough JOEs.
    function safeRJoeTransfer(address _to, uint256 _amount) internal {
        uint256 rJoeBal = rJOE.balanceOf(address(this));
        if (_amount > rJoeBal) {
            rJOE.transfer(_to, rJoeBal);
        } else {
            rJOE.transfer(_to, _amount);
        }
    }

    // Pancake has to add hidden dummy pools inorder to alter the emission,
    // here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _rJoePerSec) public onlyOwner {
        updatePool();
        rJoePerSec = _rJoePerSec;
        emit UpdateEmissionRate(msg.sender, _rJoePerSec);
    }
}
