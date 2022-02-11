pragma solidity ^0.8.0;

// This is the contract that is actually verified; it may contain some helper
// methods for the spec to access internal state, or may override some of the
// more complex methods in the original contract.

import "../munged/LaunchEvent.sol";

contract LaunchEventHarness is LaunchEvent {

    constructor(address _issuer,
        uint256 _auctionStart,
        address _token,
        uint256 _tokenIncentivesPercent,
        uint256 _floorPrice,
        uint256 _maxWithdrawPenalty,
        uint256 _fixedWithdrawPenalty,
        uint256 _maxAllocation,
        uint256 _userTimelock,
        uint256 _issuerTimelock
    ) public {
        initialize(
            _issuer,
            _auctionStart,
            _token,
            _tokenIncentivesPercent,
            _floorPrice,
            _maxWithdrawPenalty,
            _fixedWithdrawPenalty,
            _maxAllocation,
            _userTimelock,
            _issuerTimelock
        );
    }

    function getUserAllocation(address user) public returns (uint256) {
        return getUserInfo[user].allocation;
    }

    function getUserBalance(address user) public returns (uint256) {
        return getUserInfo[user].balance;
    }

    function userHasWithdrawnPair(address user) public returns (bool) {
        return getUserInfo[user].hasWithdrawnPair;
    }

    function userHasWithdrawnIncentives(address user) public returns (bool) {
        return getUserInfo[user].hasWithdrawnIncentives;
    }

    function getNewWAVAX() public returns (address){
        return address(IWAVAX(rocketJoeFactory.wavax()));
    }

    function getWAVAXbalanceOfThis() public returns (uint256){
        return WAVAX.balanceOf(address(this));
    }

    function getPenaltyCollector() public returns (address){
        return rocketJoeFactory.penaltyCollector();
    }

    function getTokenBalanceOfThis() public returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getPairBalanceOfThis() public returns (uint256) {
        return pair.balanceOf(address(this));
    }

    function getPairBalance(address user) public returns (uint256) {
        return pair.balanceOf(user);
    }

    function getTokenBalance(address user) public returns (uint256) {
        return token.balanceOf(user);
    }

    function getBalanceOfThis() public returns (uint256) {
        return address(this).balance;
    }

    function getOwner() public returns (address) {
        return Ownable(address(rocketJoeFactory)).owner();
    }  

    mapping(address => uint256) public getUserPairBalance;

    function pairBalance(address _user) public override returns (uint256) {     
        getUserPairBalance[_user] = super.pairBalance(_user);
        return getUserPairBalance[_user];
    }  


    // below are two equal methods but respresented differently
     function getPairTotalSupplyOfThis() public returns (uint256) {
        return pair.totalSupply();
    }

    function getPairTotalSupply() public returns (uint256) {
        return IJoePair(IJoeFactory(factory).getPair(address(WAVAX), address(token))).totalSupply();
    }

    function _safeTransferAVAX(address _to, uint256 _value) override internal {
        IReceiver(_to).receiveETH{value: _value}();
    }    

    function factoryGetPairWT() public returns (address){
        return factory.getPair(address(WAVAX), address(token));
    }

    function factoryGetPairTW() public returns (address){
        return factory.getPair(address(token), address(WAVAX));
    }


}

interface IReceiver {
    function receiveETH() external payable;
}

