// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Joe Token, JOE
/// @author Trader Joe
/// @dev ONLY FOR TESTS
contract ERC20Token is ERC20("Token", "token"), Ownable {
    /// @dev Mint _amount to _to. Callable only by owner
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /// @dev Destroys `_amount` tokens from `msg.sender`
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}