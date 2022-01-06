// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./RocketJoeToken.sol";

import "hardhat/console.sol";

// MasterChefJoe is a boss. He says "go f your blocks lego boy, I'm gonna use timestamp instead".
// And to top it off, it takes no risks. Because the biggest risk is operator error.
// So we make it virtually impossible for the operator of this contract to cause a bug with people's harvests.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once JOE is sufficiently
// distributed and the community can show to govern itself.
//
// With thanks to the Lydia Finance team.
//
// Godspeed and may the 10x be with you.
contract RocketJoeStakingContract is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Info of each user.
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

    // Info.
    IERC20Upgradeable moJOE; // Address of moJOE token contract.
    uint256 lastRewardTimestamp; // Last timestamp that rJOEs distribution occurs.
    uint256 accRJoePerShare; // Accumulated JOEs per share, times 1e12. See below.

    // The rJOE TOKEN!
    RocketJoeToken public rJOE;
    // rJOE tokens created per second.
    uint256 public rJoePerSec;

    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event UpdateEmissionRate(address indexed user, uint256 _rJoePerSec);

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

    // View function to see pending JOEs on frontend.
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

    // Update reward variables of the given pool to be up-to-date.
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

    // Deposit moJOE to RocketJoeStakingContract for rJOE allocation.
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

    // Withdraw moJOE from RocketJoeStakingContract.
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
