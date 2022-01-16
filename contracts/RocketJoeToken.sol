// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRocketJoeFactory.sol";

/// @title Rocket Joe Token, rJOE
/// @author Trader Joe
/// @notice Infinite supply, but burned to join launch event
contract RocketJoeToken is ERC20("RocketJoeToken", "rJOE"), Ownable {
    IRocketJoeFactory public rocketJoeFactory;

    /// @notice Modifier which checks we are at a valid state in the auction for a user to withdraw their bid
    /// @dev This essentially checks we are in phase one or two
    modifier onlyRJLaunchEvent() {
        require(
            rocketJoeFactory.isRJLaunchEvent(msg.sender),
            "RocketJoeToken: caller is not a RJLaunchEvent"
        );
        _;
    }

    /// @notice Initialise the rocketJoeFactory address
    function initialize() external {
        require(
            address(rocketJoeFactory) == address(0),
            "RocketJoeToken: already initialized"
        );

        rocketJoeFactory = IRocketJoeFactory(msg.sender);
    }

    /// @dev Creates `_amount` token to `_to`. Must only be called by the owner (RocketJoeStaking)
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /// @dev Destroys `_amount` tokens from `_from`. Callable only by a RJLaunchEvent
    function burnFrom(address _from, uint256 _amount)
        external
        onlyRJLaunchEvent
    {
        _burn(_from, _amount);
    }

    /// @dev Hook that is called before any transfer of tokens. This includes
    /// minting and burning
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(
            from == address(0) || to == address(0) || from == owner(),
            "RocketJoeToken: can't send token"
        );
    }
}
