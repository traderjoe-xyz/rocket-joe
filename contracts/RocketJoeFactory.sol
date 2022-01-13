// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./interfaces/IRocketJoeFactory.sol";
import "./interfaces/IJoeFactory.sol";
import "./interfaces/ILaunchEvent.sol";

import "./RocketJoeToken.sol";

/// @title Rocket Joe Factory
/// @author traderjoexyz
/// @notice Factory that creates Rocket Joe events.
contract RocketJoeFactory is IRocketJoeFactory, Ownable {
    address public override penaltyCollector;
    address public override eventImplementation;

    address public override rJoe;
    uint256 public override rJoePerAvax;
    address public override wavax;
    address public override router;
    address public override factory;

    uint256 private PHASE_ONE_DURATION = 3 days;
    uint256 private PHASE_TWO_DURATION = 1 days;

    mapping(address => address) public override getRJLaunchEvent;
    address[] public override allRJLaunchEvents;

    constructor(
        address _eventImplementation,
        address _rJoe,
        address _wavax,
        address _penaltyCollector,
        address _router,
        address _factory
    ) {
        require(
            _rJoe != address(0) &&
                _wavax != address(0) &&
                _penaltyCollector != address(0) &&
                _router != address(0) &&
                _factory != address(0),
            "RJFactory: Addresses can't be null address"
        );
        eventImplementation = _eventImplementation;
        rJoe = _rJoe;
        wavax = _wavax;
        penaltyCollector = _penaltyCollector;
        router = _router;
        factory = _factory;
        rJoePerAvax = 100;
    }

    function numLaunchEvents() external view override returns (uint256) {
        return allRJLaunchEvents.length;
    }

    function createRJLaunchEvent(
        address _issuer,
        uint256 _phaseOneStartTime,
        address _token,
        uint256 _tokenAmount,
        uint256 _floorPrice,
        uint256 _maxWithdrawPenalty,
        uint256 _fixedWithdrawPenalty,
        uint256 _maxAllocation,
        uint256 _userTimelock,
        uint256 _issuerTimelock
    ) external override returns (address) {
        require(
            getRJLaunchEvent[_token] == address(0),
            "RJFactory: token has already been issued"
        );
        require(_token != address(0), "RJFactory: token can't be 0 address");
        require(_token != wavax, "RJFactory: token can't be wavax");
        require(
            IJoeFactory(factory).getPair(wavax, _token) == address(0),
            "RJFactory: pair already exists"
        );

        address launchEvent = Clones.clone(eventImplementation);

        // msg.sender needs to approve RocketJoeFactory
        IERC20(_token).transferFrom(msg.sender, launchEvent, _tokenAmount);

        ILaunchEvent(payable(launchEvent)).initialize(
            _issuer,
            _phaseOneStartTime,
            _token,
            _floorPrice,
            _maxWithdrawPenalty,
            _fixedWithdrawPenalty,
            _maxAllocation,
            _userTimelock,
            _issuerTimelock
        );

        getRJLaunchEvent[_token] = launchEvent;
        allRJLaunchEvents.push(launchEvent);

        _emitLaunchedEvent(_issuer, _token, _phaseOneStartTime);

        return launchEvent;
       }

    function setRJoe(address _rJoe) external override onlyOwner {
        rJoe = _rJoe;
        emit SetRJoe(_rJoe);
    }

    function setPenaltyCollector(address _penaltyCollector)
        external
        override
        onlyOwner
    {
        penaltyCollector = _penaltyCollector;
        emit SetPenaltyCollector(_penaltyCollector);
    }

    function setRouter(address _router) external override onlyOwner {
        router = _router;
        emit SetRouter(_router);
    }

    function setFactory(address _factory) external override onlyOwner {
        factory = _factory;
        emit SetFactory(_factory);
    }

    function setRJoePerAvax(uint256 _rJoePerAvax) external override onlyOwner {
        rJoePerAvax = _rJoePerAvax;
        emit SetRJoePerAvax(_rJoePerAvax);
    }

    /// @dev This function emits an event after a new launch event has been created
    /// It is only seperated out due to `createRJLaunchEvent` having too many local variables
    function _emitLaunchedEvent(address _issuer, address _token, uint256 _phaseOneStartTime) internal {
        uint256 _phaseTwoStartTime = _phaseOneStartTime + PHASE_ONE_DURATION;
        uint256 _phaseThreeStartTime = _phaseTwoStartTime + PHASE_TWO_DURATION;

        emit RJLaunchEventCreated(
            _issuer,
            _token,
            _phaseOneStartTime,
            _phaseTwoStartTime,
            _phaseThreeStartTime,
            rJoe,
            rJoePerAvax
        );
    }
}
