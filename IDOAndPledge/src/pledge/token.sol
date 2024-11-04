// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @dev MockToken 合约，具备铸造和燃烧功能。
 * mint 和 burn 函数仅限所有者调用。
 */
contract esRNTToken is ERC20Burnable,ReentrancyGuard,Ownable {

    struct LockedEsRNT {
        uint256 amount;      // 锁定的 esRNT 数量
        uint256 startTime;   // 锁定开始时间
    }

    mapping(address => mapping(uint256 => LockedEsRNT)) public lockedEsRNTs; // 用户地址 -> eventId -> 锁定信息
    mapping(address => uint256) public lastEventId;

    uint256 public constant unlockPeriod = 30 days; // esRNT 锁定期

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {
     
    }

    /**
     * @dev 铸造新代币，仅限所有者调用。
     * @param to 接收代币的地址。
     * @param amount 铸造的代币数量。
     */
    function mint(address to, uint256 amount) external onlyOwner returns (uint256) {
        uint256 newEventId = ++lastEventId[to];
        lockedEsRNTs[to][newEventId] = LockedEsRNT({
            amount: amount,
            startTime: block.timestamp
        });
        _mint(to, amount);
        return newEventId;
    }

    /**
     * @dev 燃烧代币，仅限所有者调用。
     * @param amount 要燃烧的代币数量。
     */
    function burn(uint256 amount) public override onlyOwner {
        super.burn(amount);
    }
    
    /**
     * @dev 计算ununlocked 和burned 数量，仅限所有者调用。
     * @param user 兑换 esRNT 地址。
     * @param eventId 需要兑换的 claimId。
     */

    function calculateUnlockAndBurn(address user, uint256 eventId) external view onlyOwner returns (uint256 amount, uint256 unlocked, uint256 burned) {
        LockedEsRNT storage locked = lockedEsRNTs[user][eventId];
        require(locked.amount > 0, "Invalid or already converted event ID");

        amount = locked.amount;
        
        if (block.timestamp >= locked.startTime + unlockPeriod) {
            unlocked = amount;
        } else {
            uint256 elapsed = block.timestamp - locked.startTime;
            unlocked = (amount * elapsed) / unlockPeriod;
        }

        burned = amount - unlocked;
        require(unlocked > 0 || burned > 0, "Nothing to unlock yet");

        return (amount, unlocked, burned);
    }

    function clearLock(address user, uint256 eventId) external onlyOwner {
        delete lockedEsRNTs[user][eventId];
    }

    function getLockedEsRNT(address user, uint256 eventId) external view returns (LockedEsRNT memory) {
        return lockedEsRNTs[user][eventId];
    }
}