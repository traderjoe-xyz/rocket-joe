// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/ILaunchEvent.sol";
import "./interfaces/IRocketJoeFactory.sol";

/// @title Launch Event Lens
/// @author Trader Joe
/// @notice Helper contract to fetch launch event data
contract LaunchEventLens {
    struct LaunchEventData {
        address id;
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
        uint256 tokenReserve;
        uint256 wavaxReserve;
        IERC20Metadata token;
        IJoePair pair;
        ILaunchEvent.UserInfo userInfo;
    }

    IRocketJoeFactory public rocketJoeFactory;

    /// @notice Create a new instance with required parameters
    /// @param _rocketJoeFactory Address of the RocketJoeFactory
    constructor(address _rocketJoeFactory) {
        rocketJoeFactory = IRocketJoeFactory(_rocketJoeFactory);
    }

    /// @notice Get all launch event datas
    /// @return Array of all launch event datas
    function getAllLaunchEvents()
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
            launchEventDatas[i] = getLaunchEventData(launchEvent);
        }

        return launchEventDatas;
    }

    /// @notice Get all launch event datas with a given `_user`
    /// @param _user User to lookup
    /// @return Array of all launch event datas with user info
    function getAllLaunchEventsWithUser(address _user)
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
            launchEventDatas[i] = getUserLaunchEventData(launchEvent, _user);
        }

        return launchEventDatas;
    }

    /// @notice Get launch event data for a given launch event and user
    /// @param _launchEvent Launch event to lookup
    /// @param _user User to look up
    /// @return Launch event data for the given `_launchEvent` and `_user`
    function getUserLaunchEventData(ILaunchEvent _launchEvent, address _user)
        public
        view
        returns (LaunchEventData memory)
    {
        LaunchEventData memory launchEventData = getLaunchEventData(
            _launchEvent
        );
        launchEventData.userInfo = _launchEvent.getUserInfo(_user);
        return launchEventData;
    }

    /// @notice Get launch event data for a given launch event
    /// @param _launchEvent Launch event to lookup
    /// @return Launch event data for the given `_launchEvent`
    function getLaunchEventData(ILaunchEvent _launchEvent)
        public
        view
        returns (LaunchEventData memory)
    {
        (uint256 wavaxReserve, uint256 tokenReserve) = _launchEvent
            .getReserves();
        return
            LaunchEventData({
                id: address(_launchEvent),
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
                tokenReserve: tokenReserve,
                wavaxReserve: wavaxReserve,
                token: _launchEvent.token(),
                pair: _launchEvent.pair(),
                userInfo: ILaunchEvent.UserInfo({
                    allocation: 0,
                    balance: 0,
                    hasWithdrawnPair: false,
                    hasWithdrawnIncentives: false
                })
            });
    }
}
