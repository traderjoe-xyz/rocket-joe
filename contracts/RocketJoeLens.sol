// SPDX-License-Identifier: None

pragma solidity ^0.8.0;

import "./interfaces/ILaunchEvent.sol";
import "./interfaces/IRocketJoeFactory.sol";

/// @title Rocket Joe Lens
/// @author Trader Joe
/// @notice Helper contract to fetch rocket joe and launch event data
contract RocketJoeLens {
    struct LaunchEventData {
        uint256 auctionStart;
        uint256 phaseOneDuration;
        uint256 phaseOneNoFeeDuration;
        uint256 phaseTwoDuration;
        uint256 tokenIncentivesPercent;
        uint256 floorPrice;
        uint256 userTimelock;
        uint256 issuerTimelock;
        uint256 maxWithdrawPenalty;
        uint256 rJoePerAvax;
        IERC20Metadata token;
        IJoePair pair;
        ILaunchEvent.UserInfo userInfo;
    }

    IRocketJoeFactory public rocketJoeFactory;

    constructor(address _rocketJoeFactory) {
        rocketJoeFactory = IRocketJoeFactory(_rocketJoeFactory);
    }

    function getUserLaunchEvents(address _user)
        external
        view
        returns (LaunchEventData[] memory)
    {
        uint256 numLaunchEvents = rocketJoeFactory.numLaunchEvents();
        LaunchEventData[] memory launchEventDatas = new LaunchEventData[](
            numLaunchEvents
        );

        for (uint256 i = 0; i < numLaunchEvents; i++) {
            address launchEventAddr = rocketJoeFactory.allRJLaunchEvents(i);
            ILaunchEvent launchEvent = ILaunchEvent(launchEventAddr);
            ILaunchEvent.UserInfo memory userInfo = launchEvent.getUserInfo(
                _user
            );
            if (userInfo.balance == 0) {
                continue;
            }

            launchEventDatas[i].auctionStart = launchEvent.auctionStart();
            launchEventDatas[i].phaseOneDuration = launchEvent
                .PHASE_ONE_DURATION();
            launchEventDatas[i].phaseOneNoFeeDuration = launchEvent
                .PHASE_ONE_NO_FEE_DURATION();
            launchEventDatas[i].phaseTwoDuration = launchEvent
                .PHASE_TWO_DURATION();
            launchEventDatas[i].tokenIncentivesPercent = launchEvent
                .tokenIncentivesPercent();
            launchEventDatas[i].floorPrice = launchEvent.floorPrice();
            launchEventDatas[i].userTimelock = launchEvent.userTimelock();
            launchEventDatas[i].issuerTimelock = launchEvent.issuerTimelock();
            launchEventDatas[i].maxWithdrawPenalty = launchEvent
                .maxWithdrawPenalty();
            launchEventDatas[i].rJoePerAvax = launchEvent.rJoePerAvax();
            launchEventDatas[i].token = launchEvent.token();
            launchEventDatas[i].pair = launchEvent.pair();
            launchEventDatas[i].userInfo = userInfo;
        }

        return launchEventDatas;
    }
}
