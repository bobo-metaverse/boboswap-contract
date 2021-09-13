// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
        
import "./common/BasicStruct.sol";

// 预挖期的订单NFT, 按时间分三个批次，第一批次的可连续参与后续四个周期的挖矿，第二批次参与三个周期的挖矿，第三批次参与二个周期
// 预挖部分占5%，独立挖，16周挖完
// 剩下占95%，一共分95个周期挖，每周期分配1%份额，8周挖完
contract BoboFarmer4TradeMining is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    // Info of each user.
    struct UserInfo {
        uint256 weight;     // How many NFT weight of the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 totalWeightOfNFT;       // How many weight of all NFTs staked in this contract.
        uint256 lastRewardBlock;  // Last block number that BOBOs distribution occurs.
        uint256 accBoboPerShare; // Accumulated BOBOs per share, times 1e12. See below.
    }

    // The BOBO TOKEN!
    IBOBOToken public bobo;
    IERC721 public nftToken;           // Address of LP token contract.
    // fund contract address
    address public fundContractAddr;
    uint256 public denominator;
    uint256 public numerator;
    // BOBO tokens created per block.
    uint256 public boboPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes NFT tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Staked NFTs of each user 
    mapping (address => EnumerableSet.UintSet) private userNFTIds;
    // The block number when BOBO mining starts.
    uint256 public startBlock;
    uint256 public endBlock;

    uint256 public nftStartTime;
    uint256 public nftEndTime;

    event Deposit(address indexed user, uint256 indexed pid, uint256[] nftIds);
    event Withdraw(address indexed user, uint256 indexed pid, uint256[] nftIds);
    event WithdrawAll(address indexed user, uint256 indexed pid);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid);

    constructor(
        IBOBOToken _bobo,
        IERC721 _nftToken,
        address _fundContractAddr, 
        uint256 _boboPerBlock,   // 每区块产出
        uint256 _startBlock,     // 开始挖矿的区块号
        uint256 _endBlock,       // 结束挖矿的区块号
        uint256 _nftStartTime,   // 可抵押的nft的成交时间需大于等于此时间
        uint256 _nftEndTime      // 可抵押的nft的成交时间需小于此时间
    ) public {
        bobo = _bobo;
        nftToken = _nftToken;
        fundContractAddr = _fundContractAddr;
        boboPerBlock = _boboPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;
        nftStartTime = _nftStartTime;
        nftEndTime = _nftEndTime;

        // staking pool
        poolInfo.push(PoolInfo({
            totalWeightOfNFT: 0,
            lastRewardBlock: startBlock,
            accBoboPerShare: 0
        }));
    }

    function setFundScale(uint256 _numerator, uint256 _denominator) public onlyOwner {
        numerator = _numerator;
        denominator = _denominator;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_from < startBlock) _from = startBlock;
        if (_to > endBlock) _to = endBlock;
        return _to.sub(_from);
    }

    // View function to see pending BOBOs on frontend.
    function pendingBOBO(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accBoboPerShare = pool.accBoboPerShare;
        uint256 totalWeight = pool.totalWeightOfNFT;
        if (block.number > pool.lastRewardBlock && totalWeight != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 boboReward = multiplier.mul(boboPerBlock);
            accBoboPerShare = accBoboPerShare.add(boboReward.mul(1e12).div(totalWeight));
        }
        return user.weight.mul(accBoboPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 totalWeight = pool.totalWeightOfNFT;
        if (totalWeight == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 boboReward = multiplier.mul(boboPerBlock);  
        if (boboReward > 0) {
            uint256 fundAmount = boboReward.mul(numerator).div(denominator);
            bobo.mint(address(this), boboReward.add(fundAmount));
            bobo.approve(fundContractAddr, fundAmount);
            IBoboFund(fundContractAddr).transferBobo(fundAmount);
            pool.accBoboPerShare = pool.accBoboPerShare.add(boboReward.mul(1e12).div(totalWeight));
        }
        pool.lastRewardBlock = block.number;
    }

    // Deposit NFT to MasterChef for BOBO allocation.
    function deposit(uint256[] memory _nftIds) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.weight > 0) {
            uint256 pending = user.weight.mul(pool.accBoboPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeBOBOTransfer(msg.sender, pending);
            }
        }
        if (_nftIds.length > 0) {
            for (uint256 i = 0; i < _nftIds.length; i++) {
                NFTInfo memory nftInfo = IOrderNFT(address(nftToken)).getOrderInfo(_nftIds[i]);
                require(nftInfo.status == OrderStatus.AMMDeal, "The status of order is NOT dealed.");
                require(nftInfo.dealedTime >= nftStartTime && nftInfo.dealedTime < nftEndTime, "The dealed time of order is NOT statisfied by this contract.");
                nftToken.transferFrom(address(msg.sender), address(this), _nftIds[i]);
                uint256 nftWeight = IOrderNFT(address(nftToken)).getWeight(_nftIds[i]);
                user.weight = user.weight.add(nftWeight);
                pool.totalWeightOfNFT = pool.totalWeightOfNFT.add(nftWeight);
                userNFTIds[msg.sender].add(_nftIds[i]);
            }
        }
        user.rewardDebt = user.weight.mul(pool.accBoboPerShare).div(1e12);
        emit Deposit(msg.sender, 0, _nftIds);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256[] memory _nftIds) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(userNFTIds[msg.sender].length() >= _nftIds.length, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.weight.mul(pool.accBoboPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeBOBOTransfer(msg.sender, pending);
        }
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(userNFTIds[msg.sender].contains(_nftIds[i]), "NFT id is NOT contained in user's list.");
            userNFTIds[msg.sender].remove(_nftIds[i]);
            uint256 nftWeight = IOrderNFT(address(nftToken)).getWeight(_nftIds[i]);
            user.weight = user.weight.sub(nftWeight);
            pool.totalWeightOfNFT = pool.totalWeightOfNFT.sub(nftWeight);
            nftToken.transferFrom(address(this), address(msg.sender), _nftIds[i]);
        }
        user.rewardDebt = user.weight.mul(pool.accBoboPerShare).div(1e12);
        emit Withdraw(msg.sender, 0, _nftIds);
    }

    function withdrawAll() public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        uint256 pending = user.weight.mul(pool.accBoboPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeBOBOTransfer(msg.sender, pending);
        }
        uint256 length = userNFTIds[msg.sender].length();
        for (uint256 i = 0; i < length; i++) {
            uint256 nftId = userNFTIds[msg.sender].at(i);
            if (nftId == 0) break;
            uint256 nftWeight = IOrderNFT(address(nftToken)).getWeight(nftId);
            user.weight = user.weight.sub(nftWeight);
            pool.totalWeightOfNFT = pool.totalWeightOfNFT.sub(nftWeight);
            nftToken.transferFrom(address(this), address(msg.sender), nftId);
            userNFTIds[msg.sender].remove(nftId);
            i--;
            length--;
        }
        user.rewardDebt = user.weight.mul(pool.accBoboPerShare).div(1e12);
        emit WithdrawAll(msg.sender, 0);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        
        uint256 length = userNFTIds[msg.sender].length();
        for (uint256 i = 0; i < length; i++) {
            uint256 nftId = userNFTIds[msg.sender].at(i);
            if (nftId == 0) break;
            uint256 nftWeight = IOrderNFT(address(nftToken)).getWeight(nftId);
            user.weight = user.weight.sub(nftWeight);
            pool.totalWeightOfNFT = pool.totalWeightOfNFT.sub(nftWeight);
            nftToken.transferFrom(address(this), address(msg.sender), nftId);
            userNFTIds[msg.sender].remove(nftId);
            i--;
            length--;
        }
        
        emit EmergencyWithdraw(msg.sender, 0);
        user.weight = 0;
        user.rewardDebt = 0;
    }

    // Safe bobo transfer function, just in case if rounding error causes pool to not have enough BOBOs.
    function safeBOBOTransfer(address _to, uint256 _amount) internal {
        uint256 boboBal = bobo.balanceOf(address(this));
        if (_amount > boboBal) {
            bobo.transfer(_to, boboBal);
        } else {
            bobo.transfer(_to, _amount);
        }
    }

    function getUserNFTNumber(address _user) view public returns(uint256) {
        return userNFTIds[_user].length();
    }

    function getUserNFTIds(address _user, uint256 _fromIndex, uint256 _toIndex) view public returns(uint256[] memory nftIds) {
        uint256 length = userNFTIds[_user].length();
        if (_toIndex > length) _toIndex = length;
        require(_fromIndex < _toIndex, "Index is out of range.");
        nftIds = new uint256[](_toIndex - _fromIndex);
        for (uint256 i = _fromIndex; i < _toIndex; i++) {
            nftIds[i - _fromIndex] = userNFTIds[_user].at(i);
        }
    }
}