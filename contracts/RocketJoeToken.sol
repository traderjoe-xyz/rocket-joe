// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Rocket Joe Token, rJOE
/// @author traderjoexyz
/// @notice Infinite supply, but burned to join IDO.
contract RocketJoeToken is ERC20("RocketJoeToken", "rJOE"), Ownable {
    /// @dev Creates `_amount` token to `_to`. Must only be called by the owner (RocketJoeStaking).
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /// @dev Destroys `_amount` tokens from `msg.sender`
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}
