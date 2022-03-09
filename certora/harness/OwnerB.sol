pragma solidity ^0.8.0;

import "./LaunchEventHarness.sol";

contract OwnerB is IReceiver {
    fallback() external payable {}

    function receiveETH() external payable override {}
}
