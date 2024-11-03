// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @dev IEsRNT 接口，扩展了 IERC20，包含 mint 和 burn 函数。
 */
interface IEsRNT is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}

contract TokenPledge is ReentrancyGuard {
    IERC20 public RNT;
    IEsRNT public esRNT;

    struct StakeInfo {
        uint256 amount;          // 已质押的 RNT 数量
        uint256 unclaimed;       // 未领取的奖励
        uint256 lastUpdateTime;  // 上一次更新奖励的时间
    }

    struct LockedEsRNT {
        uint256 amount;      // 锁定的 esRNT 数量
        uint256 startTime;   // 锁定开始时间
        uint256 endTime;     // 锁定结束时间（startTime + 30天）
    }

    mapping(address => StakeInfo) public stakes;
    mapping(address => LockedEsRNT[]) public lockedEsRNTs;

    uint256 public rewardRate = 1; // 每个 RNT 每天奖励的 esRNT 数量
    uint256 public constant unlockPeriod = 30 days; // esRNT 锁定期

    // 事件定义
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event EsRNTConverted(address indexed user, uint256 amount, uint256 redeemed, uint256 burned);

    /**
     * @dev 构造函数，初始化 RNT 和 esRNT 代币。
     * @param _RNT RNT 代币地址。
     * @param _esRNT esRNT 代币地址。
     */
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
        esRNT.mint(msg.sender, reward);

        // 记录锁定信息
        // 记录锁定信息，设定锁定期为30天
        lockedEsRNTs[msg.sender].push(LockedEsRNT({
            amount: reward,
            startTime: block.timestamp,
            endTime: block.timestamp + 30 days
        }));

        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @dev 用户转换 esRNT 为 RNT，支持提前赎回但锁定部分将被销毁。
     * @param amount 需要转换的 esRNT 数量。
     */
    function convertEsRNT(uint256 amount) external AmountVerification(amount) nonReentrant {
    require(esRNT.balanceOf(msg.sender) >= amount, "Insufficient esRNT balance.");
    require(esRNT.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance.");

    uint256 redeemed = 0; // 最终赎回的 RNT 数量
    uint256 burned = 0;   // 未解锁而被销毁的 esRNT 数量

    LockedEsRNT[] storage userLocks = lockedEsRNTs[msg.sender];
    uint256 len = userLocks.length;

    for (uint256 i = 0; i < len && amount > 0; i++) {
        uint256 unlocked = 0;

        if (block.timestamp >= userLocks[i].endTime) {
            // 锁定期已结束，完全解锁
            unlocked = userLocks[i].amount;
        } else if (block.timestamp > userLocks[i].startTime) {
            // 部分解锁，按比例线性释放
            uint256 elapsed = block.timestamp - userLocks[i].startTime;
            uint256 duration = userLocks[i].endTime - userLocks[i].startTime;
            unlocked = (userLocks[i].amount * elapsed) / duration;
        }

        // `available` 是该锁仓条目中当前可以赎回的部分
        uint256 available = unlocked > userLocks[i].amount ? userLocks[i].amount : unlocked;

        if (available > 0) {
            if (available <= amount) {
                redeemed += available;
                amount -= available;
                userLocks[i].amount -= available;
            } else {
                redeemed += amount;
                userLocks[i].amount -= amount;
                amount = 0;
            }
        }
    }

    // 剩余的未到期的 esRNT 将被销毁
    if (amount > 0) {
        burned = amount;
    }

    require(redeemed > 0 || burned > 0, "Nothing to unlock yet");

    esRNT.transferFrom(msg.sender, address(this), redeemed + burned);

    if (redeemed > 0) {
        RNT.transfer(msg.sender, redeemed);
    }

    if (burned > 0) {
        esRNT.burn(burned);
    }

    emit EsRNTConverted(msg.sender, redeemed + burned, redeemed, burned);
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
    function getLockedEsRNT(address user) external view returns (LockedEsRNT[] memory) {
        return lockedEsRNTs[user];
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