// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./IJoePair.sol";

interface ILaunchEvent {
    struct UserInfo {
        uint256 allocation;
        uint256 balance;
        bool hasWithdrawnPair;
        bool hasWithdrawnIncentives;
    }

    function initialize(
        address _issuer,
        uint256 _phaseOne,
        address _token,
        uint256 _tokenIncentivesPercent,
        uint256 _floorPrice,
        uint256 _maxWithdrawPenalty,
        uint256 _fixedWithdrawPenalty,
        uint256 _maxAllocation,
        uint256 _userTimelock,
        uint256 _issuerTimelock
    ) external;

    function auctionStart() external view returns (uint256);

    function PHASE_ONE_DURATION() external view returns (uint256);

    function PHASE_ONE_NO_FEE_DURATION() external view returns (uint256);

    function PHASE_TWO_DURATION() external view returns (uint256);

    function tokenIncentivesPercent() external view returns (uint256);

    function floorPrice() external view returns (uint256);

    function userTimelock() external view returns (uint256);

    function issuerTimelock() external view returns (uint256);

    function maxAllocation() external view returns (uint256);

    function maxWithdrawPenalty() external view returns (uint256);

    function fixedWithdrawPenalty() external view returns (uint256);

    function rJoePerAvax() external view returns (uint256);

    function getReserves() external view returns (uint256, uint256);

    function token() external view returns (IERC20Metadata);

    function pair() external view returns (IJoePair);

    function pairBalance(address) external view returns (uint256);

    function getUserInfo(address) external view returns (UserInfo memory);

    function getPenalty() external view returns (uint256);
}
