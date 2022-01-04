// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IRocketJoeFactory.sol";

import "./RocketJoeToken.sol";
import "./LaunchEvent.sol";

/// @title Rocket Joe Factory
/// @author traderjoexyz
/// @notice Factory that creates Rocket Joe events.
contract RocketJoeFactory is IRocketJoeFactory, Ownable {
    address public override penaltyCollector;

    address public override rJoe;
    address public override wavax;
    address public override router;
    address public override factory;

    mapping(address => address) public override getRJLaunchEvent;
    address[] public override allRJLaunchEvent;

    constructor(
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
            "RocketJoeFactory: Addresses can't be null address"
        );
        rJoe = _rJoe;
        wavax = _wavax;
        penaltyCollector = _penaltyCollector;
        router = _router;
        factory = _factory;
    }

    function allRJLaunchEventLength() external view override returns (uint256) {
        return allRJLaunchEvent.length;
    }

    function launchEventCodeHash() external pure returns (bytes32) {
        return keccak256(type(LaunchEvent).creationCode);
    }

    function createRJLaunchEvent(
        address _issuer,
        uint256 _phaseOneStartTime,
        address _token,
        uint256 _tokenAmount,
        uint256 _floorPrice,
        uint256 _withdrawPenatlyGradient,
        uint256 _fixedWithdrawPenalty,
        uint256 _minAllocation,
        uint256 _maxAllocation,
        uint256 _userTimelock,
        uint256 _issuerTimelock
    ) external override returns (address launchEvent) {
        require(
            getRJLaunchEvent[_token] == address(0),
            "RocketJoeFactory: Rocket Joe Launch Event already exists for this token"
        );
        require(
            _token != address(0),
            "RocketJoeFactory: Token can't be null address"
        );
        require(_token != wavax, "RocketJoeFactory: Token can't be wavax");
        require(
            IJoeFactory(factory).getPair(wavax, _token) == address(0),
            "RocketJoeFactory: Pair already exists"
        );

        bytes memory bytecode = type(LaunchEvent).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_token));
        assembly {
            launchEvent := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IERC20(_token).transferFrom(msg.sender, launchEvent, _tokenAmount); // msg.sender needs to approve RocketJoeFactory

        LaunchEvent(payable(launchEvent)).initialize(
            _issuer,
            _phaseOneStartTime,
            _token,
            _floorPrice,
            _withdrawPenatlyGradient,
            _fixedWithdrawPenalty,
            _minAllocation,
            _maxAllocation,
            _userTimelock,
            _issuerTimelock
        );

        getRJLaunchEvent[_token] = launchEvent;
        allRJLaunchEvent.push(launchEvent);

        emit RJLaunchEventCreated(_token, _issuer);
    }

    function setRJoe(address _rJoe) external override onlyOwner {
        rJoe = _rJoe;
    }

    function setPenaltyCollector(address _penaltyCollector)
        external
        override
        onlyOwner
    {
        penaltyCollector = _penaltyCollector;
    }

    function setRouter(address _router) external override onlyOwner {
        router = _router;
    }

    function setFactory(address _factory) external override onlyOwner {
        factory = _factory;
    }
}
