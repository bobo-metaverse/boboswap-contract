// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
        
import "./common/BasicStruct.sol";


contract BoboMasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // 用户在某个矿池中的信息，包括股份数以及不可提现数
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;  
    }

    // 每个矿池的信息
    struct PoolInfo {
        IERC20 lpToken;           
        uint256 allocPoint;       // 本池子的权重
        uint256 lastRewardBlock;  
        uint256 accBoboPerShare;   
    }

    IBOBOToken public boboToken;
    uint256 public boboPerBlock;

    PoolInfo[] public poolList;         // 矿池信息，接口1
    
    mapping (uint256 => mapping (address => UserInfo)) public userInfoMap;  // 每个矿池中用户的信息，接口2
    
    uint256 public totalAllocPoint = 0;
    uint256 public denominator;
    uint256 public numerator;
    
    address public fundAddr;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        address _boboTokenAddress, 
        address _fundAddr
    ) public {
        boboToken = IBOBOToken(_boboTokenAddress);
        fundAddr = _fundAddr;
        numerator = 2;
        denominator = 3;
    }
    
    function setBoboPerBlock(          
        uint256 _boboPerBlock
    ) public onlyOwner {
        massUpdatePools();
        boboPerBlock = _boboPerBlock;
    }

    function setFundScale(uint256 _numerator, uint256 _denominator) public onlyOwner {
        numerator = _numerator;
        denominator = _denominator;
    }

    function setFundAddr(address _fundAddr) public onlyOwner {
        fundAddr = _fundAddr;
    }

    function poolLength() external view returns (uint256) {
        return poolList.length;
    }

    function addPool(uint256 _allocPoint, address _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.add(_allocPoint);   // 将新矿池权重加到总权重里
        poolList.push(PoolInfo({
            lpToken: (IERC20)(_lpToken),
            allocPoint: _allocPoint,
            lastRewardBlock: block.number,
            accBoboPerShare: 0
        }));
    }

    function setPoolPoint(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolList[_pid].allocPoint).add(_allocPoint);
        poolList[_pid].allocPoint = _allocPoint;
    }

    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    // 获得用户在某个矿池中可获得挖矿激励，即多少个bobo，接口4
    function pendingBobo(uint256 _pid, address _user) external view returns (uint256) {
        if (poolList.length <= _pid) return 0;
        PoolInfo storage pool = poolList[_pid];
        UserInfo storage user = userInfoMap[_pid][_user];
        if (user.amount == 0) return 0;
        uint256 accBoboPerShare = pool.accBoboPerShare;   // 当前池子每股可分多少bobo
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));   // 本合约拥有的LP token数量
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            // 计算某个池子可获得的新增的bobo数量
            uint256 boboReward = multiplier.mul(boboPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accBoboPerShare = accBoboPerShare.add(boboReward.mul(1e12).div(lpSupply));   // 此处乘以1e12，在下面会除以1e12
        }
        return user.amount.mul(accBoboPerShare).div(1e12).sub(user.rewardDebt);  
    }

    // 更新所有矿池的激励数
    function massUpdatePools() public {
        uint256 length = poolList.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolList[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));   // 本池子占有的LP数量
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);  // 获取未计算奖励的区块数（乘上加权因子）
        uint256 boboReward = multiplier.mul(boboPerBlock).mul(pool.allocPoint).div(totalAllocPoint);   // 计算本池子可获得的新的bobo激励
        if (boboReward > 0) {
            uint256 fundAmount = boboReward.mul(numerator).div(denominator);
            boboToken.mint(address(this), boboReward.add(fundAmount));
            boboToken.approve(fundAddr, fundAmount);
            IBoboFund(fundAddr).transferBobo(fundAmount);
            pool.accBoboPerShare = pool.accBoboPerShare.add(boboReward.mul(1e12).div(lpSupply));
        }

        pool.lastRewardBlock = block.number;        // 记录最新的计算过的区块高度
    }

    // 用户将自己的LP转移到矿池中进行挖矿，接口5
    // _pid: 矿池编号  
    // _amount: 抵押数量
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolList[_pid];            // 获取挖矿池
        UserInfo storage user = userInfoMap[_pid][msg.sender];  // 获取矿池中的用户信息
        updatePool(_pid);
        if (user.amount > 0) {
            // pending是用户到最新区块可提取的奖励数量
            uint256 pending = user.amount.mul(pool.accBoboPerShare).div(1e12).sub(user.rewardDebt);
            safeBoboTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);  // 将用户的lp转移到挖矿池中
        user.amount = user.amount.add(_amount);          // 将新的LP加到用户总的LP上
        user.rewardDebt = user.amount.mul(pool.accBoboPerShare).div(1e12);    
        emit Deposit(msg.sender, _pid, _amount);
    }

    // 用户从矿池中提取LP，接口6
    // _pid: 矿池编号  
    // _amount: 提取的LP数量，
    //          1: 当_amount等于0时，则只提取挖出来的BOBO
    //          2: 当_amount等于用户所有抵押的数量时，则提取挖出来的BOBO以及所有LP
    //          3: 当_amount介于两者之间时，则提取挖出来的BOBO以及指定数量的LP
    function withdraw(uint256 _pid, uint256 _lpAmount) public {
        PoolInfo storage pool = poolList[_pid];
        UserInfo storage user = userInfoMap[_pid][msg.sender];
        require(user.amount >= _lpAmount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accBoboPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeBoboTransfer(msg.sender, pending);
        }
        if (_lpAmount > 0) {
            user.amount = user.amount.sub(_lpAmount);
            pool.lpToken.safeTransfer(address(msg.sender), _lpAmount);  
        }
        user.rewardDebt = user.amount.mul(pool.accBoboPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _lpAmount, pending);
    }

    // 紧急提现LP，不再要激励
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolList[_pid];
        UserInfo storage user = userInfoMap[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // 安全转移bobo代币.
    function safeBoboTransfer(address _to, uint256 _amount) internal {
        uint256 boboBal = boboToken.balanceOf(address(this));
        if (_amount > boboBal) {
            boboToken.transfer(_to, boboBal);
        } else {
            boboToken.transfer(_to, _amount);
        }
    }
}