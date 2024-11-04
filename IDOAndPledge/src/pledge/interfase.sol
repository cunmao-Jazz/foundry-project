// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEsRNT is IERC20 {
    struct LockedEsRNT {
        uint256 amount;
        uint256 startTime;
    }

    function mint(address to, uint256 amount) external returns (uint256);
    function burn(uint256 amount) external;
    function calculateUnlockAndBurn(address user, uint256 eventId) external view returns (uint256 amount, uint256 unlocked, uint256 burned);
    function clearLock(address user, uint256 eventId) external;
    function getLockedEsRNT(address user, uint256 eventId) external view returns (LockedEsRNT memory);

}