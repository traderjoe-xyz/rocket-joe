// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRocketJoeFactory.sol";

/// @title Rocket Joe Token, rJOE
/// @author traderjoexyz
/// @notice Infinite supply, but burned to join IDO
contract RocketJoeToken is ERC20("RocketJoeToken", "rJOE"), Ownable {
    IRocketJoeFactory public rocketJoeFactory;
    bool private initialized;

    /// @notice Initialise the rocketJoeFactory address
    function initialize() external {
        require(!initialized, "RocketJoeToken: Already initialized");

        rocketJoeFactory = IRocketJoeFactory(msg.sender);
        initialized = true;
    }

    /// @dev Creates `_amount` token to `_to`. Must only be called by the owner (RocketJoeStaking)
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /// @dev Destroys `_amount` tokens from `msg.sender`
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    /// @dev Hook that is called before any transfer of tokens. This includes
    /// minting and burning
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(
            from == address(0) ||
            to == address(0) ||
            from == owner() ||
            rocketJoeFactory.isLaunchEvent(from) ||
            rocketJoeFactory.isLaunchEvent(to),
            "rJOE: can't send token"
        );
    }
}
