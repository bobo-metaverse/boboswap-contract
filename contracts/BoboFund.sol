// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
        
import "./common/BasicStruct.sol";

// Bobo基金合约，挖出的BOBO代币会分配给开发者团队、投资人、社区发展基金
// 开发者占15%
// 投资人占15%
// 生态发展基金10%
contract BoboFund is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;  
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 totalDepositAmount;
        uint256 allocPoint;       
        uint256 lastRewardBoboAmount;  
        uint256 accBoboPerShare; 
    }

    IERC20 public bobo;

    PoolInfo[] public poolInfo;
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;
    uint256 public totalBoboAmount;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        IERC20 _bobo,              
        uint256 _startBlock
    ) public {
        bobo = _bobo;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // 添加新矿池，指定矿池权重、LP代币合约地址以及是否更新所有矿池
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.add(_allocPoint);   // 将新矿池权重加到总权重里
        poolInfo.push(PoolInfo({
            totalDepositAmount: 0,
            allocPoint: _allocPoint,
            lastRewardBoboAmount: 0,
            accBoboPerShare: 0
        }));
    }
    // 管理员添加可以挖矿的用户
    function deposit(uint256 _pid, address _user, uint256 _amount) public onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];            // 获取挖矿池
        UserInfo storage user = userInfo[_pid][_user];  // 获取狂池中的用户信息
        updatePool(_pid);
        if (user.amount > 0) {
            // pending是用户到最新区块可提取的奖励数量
            uint256 pending = user.amount.mul(pool.accBoboPerShare).div(1e12).sub(user.rewardDebt);
            safeBoboTransfer(_user, pending);
        }
        pool.totalDepositAmount = pool.totalDepositAmount.add(_amount);
        user.amount = user.amount.add(_amount);          // 将新的LP加到用户总的LP上
        user.rewardDebt = user.amount.mul(pool.accBoboPerShare).div(1e12);    
        emit Deposit(_user, _pid, _amount);
    }

    // 获得用户在某个矿池中可获得挖矿激励，即多少个bobo
    function pendingBobo(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accBoboPerShare = pool.accBoboPerShare;
        if (pool.totalDepositAmount != 0) {
            // 计算某个池子可获得的新增的bobo数量
            uint256 boboReward = totalBoboAmount.sub(pool.lastRewardBoboAmount).mul(pool.allocPoint).div(totalAllocPoint);
            accBoboPerShare = accBoboPerShare.add(boboReward.mul(1e12).div(pool.totalDepositAmount));
        }
        return user.amount.mul(accBoboPerShare).div(1e12).sub(user.rewardDebt);  
    }

    // 更新所有矿池的激励数
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // 更新指定矿池的激励，此处会给开发者额外10%的bobo激励
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
                
        if (pool.lastRewardBoboAmount == totalBoboAmount) {
            return;
        }
        uint256 boboReward = totalBoboAmount.sub(pool.lastRewardBoboAmount).mul(pool.allocPoint).div(totalAllocPoint);   // 计算本池子可获得的新的bobo激励
        pool.accBoboPerShare = pool.accBoboPerShare.add(boboReward.mul(1e12).div(pool.totalDepositAmount));  // 计算每个lp可分到的bobo数量
        pool.lastRewardBoboAmount = totalBoboAmount;        // 记录最新的计算过的BOBO数量
    }

    function transferBobo(uint256 _boboAmount) public {
        bobo.safeTransferFrom(msg.sender, address(this), _boboAmount);
        totalBoboAmount = totalBoboAmount.add(_boboAmount);
    }
    // 用户从矿池中提取所有可提取的BOBO
    function withdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount > 0, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accBoboPerShare).div(1e12).sub(user.rewardDebt);
        safeBoboTransfer(msg.sender, pending);
        user.rewardDebt = user.amount.mul(pool.accBoboPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, pending);
    }

    // 安全转移bobo代币.
    function safeBoboTransfer(address _to, uint256 _amount) internal {
        uint256 boboBal = bobo.balanceOf(address(this));
        if (_amount > boboBal) {
            bobo.transfer(_to, boboBal);
        } else {
            bobo.transfer(_to, _amount);
        }
    }
}