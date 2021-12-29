// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/IWAVAX.sol";
import "./interface/IJoeRouter02.sol";
import "./interface/IJoeFactory.sol";
import "./interface/IJoePair.sol";
import "./interface/IRocketJoeFactory.sol";

import "./RocketJoeToken.sol";
import "./LaunchEvent.sol";

/// @title Rocket Joe Factory
/// @author traderjoexyz
/// @notice Factory that creates Rocket Joe events.
contract RocketJoeFactory is IRocketJoeFactory, Ownable{
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => address) public override getRJLaunchEvent;
    address[] public override allRJLaunchEvent;

    event RJLaunchEventCreated(address indexed token, address indexed issuer);

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
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
        require(getRJLaunchEvent[_token] == address(0), "RocketJoeFactory: Rocket Joe Launch Event already exists for this token");
        require(_token != address(0), "RocketJoeFactory: Token can't be zero address");

        bytes memory bytecode = type(LaunchEvent).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_token));
        assembly {
            launchEvent := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        LaunchEvent(launchEvent).initialize(
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

        IERC20(_token).transfer(launchEvent, _tokenAmount);

        emit RJLaunchEventCreated(_token, _issuer);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "RocketJoeFactory: Forbidden");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "RocketJoeFactory: Forbidden");
        feeToSetter = _feeToSetter;
    }
}
