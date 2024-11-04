// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfase.sol";


contract TokenPledge is ReentrancyGuard {
    IERC20 public RNT;
    IEsRNT public esRNT;

    struct StakeInfo {
        uint256 amount;          // 已质押的 RNT 数量
        uint256 unclaimed;       // 未领取的奖励
        uint256 lastUpdateTime;  // 上一次更新奖励的时间
    }


    mapping(address => StakeInfo) public stakes;

    uint256 public rewardRate = 1; // 每个 RNT 每天奖励的 esRNT 数量
    uint256 public constant unlockPeriod = 30 days; // esRNT 锁定期

    // 事件定义
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward, uint256 eventId);
    event EsRNTConverted(address indexed user, uint256 amount, uint256 redeemed, uint256 burned, uint256 eventId);

    constructor(IERC20 _RNT, IEsRNT _esRNT){
        RNT = _RNT;
        esRNT = _esRNT;
    }

    // 修饰符：验证账户地址有效性
    modifier AccountVerification(address account){
        require(account != address(0), "Invalid address");
        _;
    }

    // 修饰符：验证金额大于零
    modifier AmountVerification(uint256 amount){
        require(amount > 0, "Insufficient funds");
        _;
    }

    /**
     * @dev 用户质押 RNT 代币。
     * @param amount 质押的 RNT 数量。
     */
    function stake(uint256 amount) public AmountVerification(amount) nonReentrant {
        require(RNT.balanceOf(msg.sender) >= amount, "Insufficient token balance.");
        require(RNT.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance.");
        _updateReward(msg.sender);

        RNT.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender].amount += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @dev 用户解押 RNT 代币。
     * @param amount 解押的 RNT 数量。
     */
    function unstake(uint256 amount) public AmountVerification(amount) nonReentrant {
        require(stakes[msg.sender].amount >= amount, "Insufficient staked balance");
        _updateReward(msg.sender);

        stakes[msg.sender].amount -= amount;
        RNT.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev 用户领取 esRNT 奖励。
     */
    function claim() external nonReentrant {
        _updateReward(msg.sender);

        uint256 reward = stakes[msg.sender].unclaimed;
        require(reward > 0, "No reward to claim");

        stakes[msg.sender].unclaimed = 0;
        
        uint256 eventId = esRNT.mint(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward, eventId);
    }

    /**
     * @dev 用户使用esRNT 兑换 RNT 奖励。
    * @param eventId claim  eventId。
     */
    function convertEsRNT(uint256 eventId) external nonReentrant {
        (uint256 amount, uint256 unlocked, uint256 burned) = esRNT.calculateUnlockAndBurn(msg.sender, eventId);

        require(esRNT.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        if (unlocked > 0) {
            RNT.transfer(msg.sender, unlocked);
        }
        
        if (burned > 0) {
            esRNT.burn(burned);
        }

        esRNT.clearLock(msg.sender, eventId);

        emit EsRNTConverted(msg.sender, amount, unlocked, burned, eventId);
}

    /**
     * @dev 获取用户的质押信息。
     * @param user 用户地址。
     * @return amount 已质押的 RNT 数量。
     * @return unclaimed 未领取的 esRNT 奖励。
     * @return lastUpdateTime 上一次更新奖励的时间。
     */
    function getStakeInfo(address user) external view returns (uint256 amount, uint256 unclaimed, uint256 lastUpdateTime) {
        StakeInfo storage stakeInfo = stakes[user];
        return (stakeInfo.amount, stakeInfo.unclaimed, stakeInfo.lastUpdateTime);
    }

    /**
     * @dev 获取用户的所有锁定 esRNT 信息。
     * @param user 用户地址。
     * @return 用户的所有 LockedEsRNT 数组。
     */
    function getLockedEsRNT(address user, uint256 eventId) external view returns (IEsRNT.LockedEsRNT memory) {
        return esRNT.getLockedEsRNT(user, eventId);
    }

    /**
     * @dev 内部函数，更新用户的未领取奖励。
     * @param user 用户地址。
     */
    function _updateReward(address user) internal AccountVerification(user){
        StakeInfo storage stakeInfo = stakes[user];
        if (stakeInfo.amount > 0){
            uint256 timeElapsed = block.timestamp - stakeInfo.lastUpdateTime;
            uint256 reward = (stakeInfo.amount * rewardRate * timeElapsed) / 1 days;
            stakeInfo.unclaimed += reward;
        }
        stakeInfo.lastUpdateTime = block.timestamp;
    }
}