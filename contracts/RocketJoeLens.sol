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
            if (userInfo.balance > 0) {
                launchEventDatas[i] = getLaunchEventData(launchEvent);
            }
        }

        return launchEventDatas;
    }

    function getLaunchEventData(ILaunchEvent _launchEvent)
        public
        view
        returns (LaunchEventData memory)
    {
        return
            LaunchEventData({
                auctionStart: _launchEvent.auctionStart(),
                phaseOneDuration: _launchEvent.PHASE_ONE_DURATION(),
                phaseOneNoFeeDuration: _launchEvent.PHASE_ONE_NO_FEE_DURATION(),
                phaseTwoDuration: _launchEvent.PHASE_TWO_DURATION(),
                tokenIncentivesPercent: _launchEvent.tokenIncentivesPercent(),
                floorPrice: _launchEvent.floorPrice(),
                userTimelock: _launchEvent.userTimelock(),
                issuerTimelock: _launchEvent.issuerTimelock(),
                maxWithdrawPenalty: _launchEvent.maxWithdrawPenalty(),
                rJoePerAvax: _launchEvent.rJoePerAvax(),
                token: _launchEvent.token(),
                pair: _launchEvent.pair(),
                userInfo: _launchEvent.getUserInfo(msg.sender)
            });
    }
}
