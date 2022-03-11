pragma solidity ^0.8.0;

// This is the contract that is actually verified; it may contain some helper
// methods for the spec to access internal state, or may override some of the
// more complex methods in the original contract.

import "../munged/RocketJoeStaking.sol";

// TODO: change the name and supercontract and add any necessary harnessing
contract RocketJoeStakingHarness is RocketJoeStaking {

    function userJoeStaked(address user) public view returns (uint256) {
        return userInfo[user].amount;
    }

    function userRewardDebt(address user) public view returns (uint256) {
        return userInfo[user].rewardDebt;
    }

    function getOwner() public view returns (address) {
        return owner();
    }

    constructor(IERC20Upgradeable _joe, RocketJoeToken _rJoe, uint256 _rJoePerSec, uint256 _startTime) {
        initialize(_joe, _rJoe, _rJoePerSec, _startTime);
    }
}

