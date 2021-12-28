// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// RocketJoeToken, rJoe.
contract RocketJoeToken is ERC20("RocketJoeToken", "rJOE"), Ownable {
    /// @notice Infinite supply, but burned to join IDO.

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (RocketJoeStakingContract).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
