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

    mapping(address => address) public override getRJLaunchEvent;
    address[] public override allRJLaunchEvent;

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

    function allRJLaunchEventLength() external view override returns (uint256) {
        return allRJLaunchEvent.length;
    }

    function createRJLaunchEvent(
        address _issuer,
        uint256 _phaseOne,
        address _token,
        uint256 _tokenAmount,
        uint256 _floorPrice,
        uint256 _withdrawPenaltyGradient,
        uint256 _fixedWithdrawPenalty,
        uint256 _minAllocation,
        uint256 _maxAllocation,
        uint256 _userTimelock,
        uint256 _issuerTimelock
    ) external override returns (address) {
        require(getRJLaunchEvent[_token] == address(0), "RJFactory: token has already been issued");
        require(_token != address(0), "RJFactory: token can't be 0 address");
        require(_token != wavax, "RJFactory: token can't be wavax");
        require(IJoeFactory(factory).getPair(wavax, _token) == address(0), "RJFactory: pair already exists");

        //bytes memory bytecode = type(LaunchEvent).creationCode;
        //bytes32 salt = keccak256(abi.encodePacked(_token));
        //assembly {
        //    launchEvent := create2(0, add(bytecode, 32), mload(bytecode), salt)
        //}
        address launchEvent = Clones.clone(eventImplementation);


        IERC20(_token).transferFrom(msg.sender, launchEvent, _tokenAmount); // msg.sender needs to approve RocketJoeFactory

        ILaunchEvent(payable(launchEvent)).initialize(
            _issuer,
            _phaseOne,
            _token,
            _floorPrice,
            _withdrawPenaltyGradient,
            _fixedWithdrawPenalty,
            _minAllocation,
            _maxAllocation,
            _userTimelock,
            _issuerTimelock
        );

        getRJLaunchEvent[_token] = launchEvent;
        allRJLaunchEvent.push(launchEvent);

        emit RJLaunchEventCreated(_token, _issuer);
        return launchEvent;
    }

    function setRJoe(address _rJoe) external override onlyOwner {
        rJoe = _rJoe;
    }

    function setPenaltyCollector(address _penaltyCollector) external override onlyOwner {
        penaltyCollector = _penaltyCollector;
    }

    function setRouter(address _router) external override onlyOwner {
        router = _router;
    }

    function setFactory(address _factory) external override onlyOwner {
        factory = _factory;
    }

    function setRJoePerAvax(uint256 _rJoePerAvax) external override onlyOwner {
        rJoePerAvax = _rJoePerAvax;
    }
}
