pragma solidity ^0.8.0;

import "./LaunchEventHarness.sol";

contract OwnerA is IReceiver{

    fallback() external payable {}
    function receiveETH() external override payable {}
}