// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


import "./common/BasicStruct.sol";
import "./SwapInterfaces.sol";

// 交易在 quickSwap
// 挖矿在 sushiSwap => matic&sushi
contract StratMaticSushi is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public BOBO;

    address public constant sushiFactory = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
    address public constant sushiRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address public constant sushiMasterChef = 0x0769fd68dFb93167989C6f7254cd0D766Fb2841F;   // APY较高    

    address public constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address public constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant SUSHI = 0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a;
    
    address public constant deadAddr = 0x000000000000000000000000000000000000dEaD; 

    uint256 public minFarmAmount = 1e6;
    address public earnedTokenOne = WMATIC;             // 挖出的代币地址
    address public earnedTokenTwo = SUSHI;             // 挖出的代币地址
    address public burnedTokenAddress;          // 待销毁的代币地址，用挖出的代币地址的一部分去回购此代币并销毁它
    
    address public curRouter = sushiRouter;
    address public curFactory = sushiFactory;

    address public curMasterChef = sushiMasterChef;
    mapping(address => mapping(address => uint256)) public curPidMap;

    // BOBO_Farmer池子的LP代币地址，用户就是在挖这个币（通过卖出收益来换此币）
    address public wantAddress;           

    address public govAddress; 
    EnumerableSet.AddressSet private allowedFarmTokenSet;

    mapping(address => uint256) public wantLockedTotalMap;  
    mapping(address => uint256) public sharesTotalMap; 

    
    uint256 public constant BasePercent = 10000;
    // 回购销毁BOBO比例
    uint256 public burnedBOBORate = 0;
    uint256 public constant burnedBOBORateUL = 8000;
    uint256 public totalBurnedBOT;

    // 开发者基金，试运营期间提取50%，正式运营期间提10%
    address public devFundAddr;
    uint256 public devFundFee = 5000; 
    uint256 public constant devFundFeeUL = 2000;

    modifier onlyGov() {
        require(msg.sender == govAddress, "StratMaticSushi: !gov");
        _;
    }

    constructor(
        address _boboAddr,
        address _boboFarmer
    ) public {
        govAddress = msg.sender;
        devFundAddr = msg.sender;
        BOBO = _boboAddr;
        burnedTokenAddress = _boboAddr;
        
        addFarmToken(USDT);
        addFarmToken(USDC);
        
        // belows are all pids of Pancake masterchef, and MDEX is [USDT][BUSD] = 0x20;[USDT][USDC] = 0x21;[BUSD][USDC] = 0;       
        curPidMap[USDT][USDC] = 0x08;
        curPidMap[USDC][USDT] = 0x08;

        transferOwnership(_boboFarmer);
        setAllowedBalance();
    }
    
    // 迁移策略过程中，由farmer调用，初始化新策略的股份和抵押金额
    function initTotalShareAndLocked(address _tokenAddr, uint256 _totalShare, uint256 _totalLocked) external onlyOwner {
        sharesTotalMap[_tokenAddr] = _totalShare;
        wantLockedTotalMap[_tokenAddr] = _totalLocked;
    }
    // 迁移策略过程中，由farmer调用，清理旧策略的资产
    function clearAndTransferTokens(address _tokenAddr) external onlyOwner returns(uint256, uint256) {
        require(isFarmToken(_tokenAddr), "StratMaticSushi: NOT farm token.");
        address anotherToken = _tokenAddr == USDT ? USDC : USDT;
        claimRewardAndCompound(_tokenAddr, anotherToken);

        withdrawAllLP(_tokenAddr, anotherToken);

        uint256 amount = IERC20(_tokenAddr).balanceOf(address(this));
        if (amount > 0)
            IERC20(_tokenAddr).transfer(msg.sender, amount);

        return (sharesTotalMap[_tokenAddr], wantLockedTotalMap[_tokenAddr]);
    }
    
    // 设置新的交易所以及挖矿信息
    function setNewSwapInfo(address _factory, address _router, address _masterChef, 
                            address _earnedTokenAddrOne, address _earnedTokenAddrTwo, 
                            address[] memory _token0s, address[] memory _token1s, uint256[] memory _pids) external onlyGov {
        require(_factory != curFactory && _router != curRouter && _masterChef != curMasterChef, "StratMaticSushi: new addresses can NOT be as same as old.");
        require(_token0s.length == _token1s.length && _token0s.length == _pids.length, "StratMaticSushi ERROR: token0s,token1s and pids' length should be equal.");
        
        withdrawAllLP(USDT, USDC);
        
        curFactory = _factory;
        curRouter = _router;
        curMasterChef = _masterChef;
        earnedTokenOne = _earnedTokenAddrOne;
        earnedTokenTwo = _earnedTokenAddrTwo;
        
        for(uint256 i = 0; i < _pids.length; i++) {
            curPidMap[_token0s[i]][_token1s[i]] = _pids[i];
            curPidMap[_token1s[i]][_token0s[i]] = _pids[i];
        }
        
        setAllowedBalance();
        
        _farm();
    }

    function setAllowedBalance() private {
        IERC20(USDT).safeIncreaseAllowance(curRouter, uint256(-1));
        IERC20(USDC).safeIncreaseAllowance(curRouter, uint256(-1));
        IERC20(SUSHI).safeIncreaseAllowance(curRouter, uint256(-1));
        IERC20(WMATIC).safeIncreaseAllowance(curRouter, uint256(-1));
        address pairAddr = ICommonFactory(curFactory).getPair(USDT, USDC);
        IERC20(pairAddr).safeIncreaseAllowance(curRouter, uint256(-1));
    }
    
    // 获取交易对的资产数量
    function getBalances(address _token0, address _token1) public view returns(uint256, uint256) {        
        address pairAddr = ICommonFactory(curFactory).getPair(_token0, _token1);
        uint256 totalLPBalance = ICommonPair(pairAddr).totalSupply();
        uint256 myLPBalance = 0;
        (myLPBalance, ) = ICommonMasterChef(curMasterChef).userInfo(curPidMap[_token0][_token1], address(this));

        (uint256 reserve0, uint256 reserve1, ) = ICommonPair(pairAddr).getReserves();
        address token0 = ICommonPair(pairAddr).token0();
        if (token0 == _token0) {
            return (reserve0.mul(myLPBalance).div(totalLPBalance), reserve1.mul(myLPBalance).div(totalLPBalance));
        } else {
            return (reserve1.mul(myLPBalance).div(totalLPBalance), reserve0.mul(myLPBalance).div(totalLPBalance));
        }
    }

    // 从Farm合约中获取新的抵押
    function deposit(uint256 _wantAmt, address _wantAddr) public onlyOwner whenNotPaused returns (uint256) {
        require(isFarmToken(_wantAddr), "StratMaticSushi: NOT farm token.");
        // 先将want代币从挖矿合约中转移到策略合约
        IERC20(_wantAddr).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        // 
        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotalMap[_wantAddr] > 0) {
            sharesAdded = _wantAmt
                .mul(sharesTotalMap[_wantAddr])
                .div(wantLockedTotalMap[_wantAddr]);
        }
        sharesTotalMap[_wantAddr] = sharesTotalMap[_wantAddr].add(sharesAdded);
        wantLockedTotalMap[_wantAddr] = wantLockedTotalMap[_wantAddr].add(_wantAmt);
        
        _farm();

        return sharesAdded;
    }

    // 此方法即复投，将本合约中的BUSD-USDT LP复投到MDEX空投合约中进行挖矿
    // 可以由任意账号调用
    function farm() public nonReentrant {
        _farm();
    }

    // 将USDT/BUSD/USDC进行组合后复投
    function _farm() internal {
        addLiquidAndFarm(USDT, USDC);
    }
    
    // 将本合约拥有的两种token组合后提供流动性，并将LP抵押进行挖矿
    function addLiquidAndFarm(address _tokenA, address _tokenB) internal {
        uint256 tokenABalance = IERC20(_tokenA).balanceOf(address(this));
        uint256 tokenBBalance = IERC20(_tokenB).balanceOf(address(this));
        
        if (tokenABalance > minFarmAmount && tokenBBalance > minFarmAmount && curPidMap[_tokenA][_tokenB] > 0) {                
            (,,uint256 liquidity) = ICommonRouter(curRouter).addLiquidity(_tokenA, _tokenB, tokenABalance, tokenBBalance, 0, 0, address(this), now);
            
            address pairAddr = ICommonFactory(curFactory).getPair(_tokenA, _tokenB);
            IERC20(pairAddr).safeIncreaseAllowance(
                curMasterChef,
                liquidity
            );
            ICommonMasterChef(curMasterChef).deposit(curPidMap[_tokenA][_tokenB], liquidity, address(this));
        }
    }
    
    function convertThreePath(address[3] memory path) private pure returns(address[] memory newPath) {
        newPath = new address[](path.length);
        for (uint256 i = 0; i < path.length; i++) {
            newPath[i] = path[i];
        }
    }
    
    function convertTwoPath(address[2] memory path) private pure returns(address[] memory newPath) {
        newPath = new address[](path.length);
        for (uint256 i = 0; i < path.length; i++) {
            newPath[i] = path[i];
        }
    }
    // 取出由两个token组成的LP的挖矿收益cake/MDX，分配后进行复投
    function claimRewardAndCompound(address _tokenA, address _tokenB) internal {
        uint256 earnedAmountTokenOne = 0;
        uint256 earnedAmountTokenTwo = 0;
        
        // 0: 提取所有WMATIC&SUSHI
        ICommonMasterChef(curMasterChef).harvest(curPidMap[_tokenA][_tokenB], address(this));  
        earnedAmountTokenOne = IERC20(earnedTokenOne).balanceOf(address(this));
        earnedAmountTokenTwo = IERC20(earnedTokenTwo).balanceOf(address(this));
        
        // 1: 先将挖矿所得平均换成两种代币，在组成对应的LP后继续抵押挖矿
        uint256 compoundRate = BasePercent.sub(burnedBOBORate).sub(devFundFee);

        uint256 compoundAmountTokenOne = earnedAmountTokenOne.mul(compoundRate).div(BasePercent);
        uint256 compoundAmountTokenTwo = earnedAmountTokenTwo.mul(compoundRate).div(BasePercent);

        uint256 tokenABalance = IERC20(_tokenA).balanceOf(address(this));
        uint256 tokenBBalance = IERC20(_tokenB).balanceOf(address(this));
        
        // 将挖矿所得的代币ONE(sushi)兑换成TokenA（USDT）和TokenB（USDC）
        if (compoundAmountTokenOne > 0) {
            ICommonRouter(curRouter)
                .swapExactTokensForTokens(
                compoundAmountTokenOne.div(2),
                0,
                convertTwoPath([earnedTokenOne, _tokenA]),
                address(this),
                now
            );
            ICommonRouter(curRouter)
                .swapExactTokensForTokens(
                compoundAmountTokenOne.div(2),
                0,
                convertTwoPath([earnedTokenOne, _tokenB]),
                address(this),
                now
            );
        }
        // 将挖矿所得的代币TWO(matic)兑换成TokenA（USDT）和TokenB（USDC）
        if (compoundAmountTokenTwo > 0) {
            ICommonRouter(curRouter)
                .swapExactTokensForTokens(
                compoundAmountTokenTwo.div(2),
                0,
                convertTwoPath([earnedTokenTwo, _tokenA]),
                address(this),
                now
            );
            ICommonRouter(curRouter)
                .swapExactTokensForTokens(
                compoundAmountTokenTwo.div(2),
                0,
                convertTwoPath([earnedTokenTwo, _tokenB]),
                address(this),
                now
            );
        }

        uint256 tokenANewBalance = IERC20(_tokenA).balanceOf(address(this));
        uint256 tokenBNewBalance = IERC20(_tokenB).balanceOf(address(this));
        
        // 由于上面兑换出了USDT和USDC，所以此处需要增加wantLockedTotalMap
        wantLockedTotalMap[_tokenA] = wantLockedTotalMap[_tokenA].add(tokenANewBalance.sub(tokenABalance));
        wantLockedTotalMap[_tokenB] = wantLockedTotalMap[_tokenB].add(tokenBNewBalance.sub(tokenBBalance));

        addLiquidAndFarm(_tokenA, _tokenB);

        // 2: 回购并销毁Bobo
        uint256 burnedAmountTokenOne = 0;
        if (burnedBOBORate > 0) {
            burnedAmountTokenOne = earnedAmountTokenOne.mul(burnedBOBORate).div(BasePercent);
            ICommonRouter(curRouter)
                .swapExactTokensForTokens(
                    burnedAmountTokenOne,
                    0,
                    convertThreePath([earnedTokenOne, USDT, BOBO]),
                    deadAddr,
                    now
            );
        }

        uint256 burnedAmountTokenTwo = 0;
        if (burnedBOBORate > 0) {
            burnedAmountTokenTwo = earnedAmountTokenOne.mul(burnedBOBORate).div(BasePercent);
            ICommonRouter(curRouter)
                .swapExactTokensForTokens(
                    burnedAmountTokenTwo,
                    0,
                    convertThreePath([earnedTokenTwo, USDT, BOBO]),
                    deadAddr,
                    now
            );
        }
        
        // 3：剩余部分归基金会
        uint256 leftAmountTokenOne = earnedAmountTokenOne.sub(compoundAmountTokenOne).sub(burnedAmountTokenOne);
        if (leftAmountTokenOne > 0)
            IERC20(earnedTokenOne).safeTransfer(devFundAddr, leftAmountTokenOne);

        uint256 leftAmountTokenTwo = earnedAmountTokenTwo.sub(compoundAmountTokenTwo).sub(burnedAmountTokenTwo);
        if (leftAmountTokenTwo > 0)
            IERC20(earnedTokenTwo).safeTransfer(devFundAddr, leftAmountTokenTwo);

        // 4：复投
        _farm();
    }

    function earn() public {
        claimRewardAndCompound(USDT, USDC);
    }

    // 从满足数量要求的LP中提取token，并将token直接转到调用者（此处为farmer合约）
    function withdrawOneToken(uint256 _wantAmt, address _withdrawToken, address _peerToken) internal returns(uint256) {
        uint256 curAmount = IERC20(_withdrawToken).balanceOf(address(this));
        if (curAmount < _wantAmt) {
            uint256 restAmountOut = _wantAmt.sub(curAmount);
            (uint256 amount0, ) = getBalances(_withdrawToken, _peerToken);  // 获取当前流动性挖矿中的token数量

            // 从流动性挖矿中提取出token
            if (amount0 >= restAmountOut) {
                withdrawToken0FromLP(restAmountOut, amount0, _withdrawToken, _peerToken);
                restAmountOut = 0;
            } else if (amount0 > 0) {
                withdrawToken0FromLP(amount0, amount0, _withdrawToken, _peerToken);  // 此处已把所有流动性都取出了
                restAmountOut = restAmountOut.sub(amount0);
            }
            if (restAmountOut > 0) {
                uint256[] memory amounts = ICommonRouter(curRouter).getAmountsIn(restAmountOut, convertTwoPath([_peerToken, _withdrawToken]));
                uint256 curPeerTokenAmount = IERC20(_peerToken).balanceOf(address(this));
                require(curPeerTokenAmount >= amounts[0], "StratMaticSushi: left amount is NOT enough!");
                ICommonRouter(curRouter)
                    .swapTokensForExactTokens(
                        restAmountOut,
                        uint256(-1),
                        convertTwoPath([_peerToken, _withdrawToken]),
                        address(this),
                        now
                );
            }
        }
        
        IERC20(_withdrawToken).safeTransfer(msg.sender, _wantAmt);
        return _wantAmt;
    }


    // 从LP中提取出数量为_withrawAmount的token0
    // 1: 先从矿池里提取对应数量的LP
    // 2: 从LP撤出流动性池子，本合约获得所需数量的token0，附带token1
    function withdrawToken0FromLP(uint256 _withrawAmount, uint256 _totalAmount, address _token0, address _token1) internal {
        uint256 myLPBalance = 0;
        (myLPBalance, ) = ICommonMasterChef(curMasterChef).userInfo(curPidMap[_token0][_token1], address(this));

        uint256 withdrawLPBalance = _withrawAmount.mul(myLPBalance).div(_totalAmount);
        // 此处会提取指定数量的LP token，以及所有WMATIC&Sushi奖励
        ICommonMasterChef(curMasterChef).withdrawAndHarvest(curPidMap[_token0][_token1], withdrawLPBalance, address(this));  

        ICommonRouter(curRouter).removeLiquidity(
            _token0,
            _token1,
            withdrawLPBalance,
            0,
            0,
            address(this),
            now
        );
    }
    // 提取出所有的LP（TOKEN0&TOKEN1）
    function withdrawAllLP(address _token0, address _token1) internal {
        (uint256 myLPBalance, ) = ICommonMasterChef(curMasterChef).userInfo(curPidMap[_token0][_token1], address(this));
        
        if (myLPBalance > 0) {
            // 此处会提取WMATIC奖励，以及LP token
            ICommonMasterChef(curMasterChef).withdrawAndHarvest(curPidMap[_token0][_token1], myLPBalance, address(this));
    
            ICommonRouter(curRouter).removeLiquidity(
                _token0,
                _token1,
                myLPBalance,
                0,
                0,
                address(this),
                now
            );
        }
    }


    // 用户提现抵押的稳定币（包括产生的利息）
    // 1. 从MDEX董事会中撤出MDX单币
    // 2. 计算出用户占有的股份数，从总数中减去
    // 3. 将用户提取的MDX转给bot挖矿合约
    function withdraw(uint256 _wantAmt, address _wantAddr) public onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0, "StratMaticSushi: _wantAmt <= 0");
        require(isFarmToken(_wantAddr), "StratMaticSushi: NOT farm token.");
        
        address token0 = _wantAddr == USDT ?  USDC : USDT;
        uint256 realAmount = withdrawOneToken(_wantAmt, _wantAddr, token0);        

        // 2. 计算出用户占有的股份数，从总数中减去        
        uint256 sharesRemoved = realAmount.mul(sharesTotalMap[_wantAddr]).div(wantLockedTotalMap[_wantAddr]);
        if (sharesRemoved.mul(wantLockedTotalMap[_wantAddr]) < realAmount.mul(sharesTotalMap[_wantAddr])) {
            sharesRemoved = sharesRemoved.add(1);
        }
        if (sharesRemoved > sharesTotalMap[_wantAddr]) {
            sharesRemoved = sharesTotalMap[_wantAddr];
        }
        sharesTotalMap[_wantAddr] = sharesTotalMap[_wantAddr].sub(sharesRemoved);
        wantLockedTotalMap[_wantAddr] = wantLockedTotalMap[_wantAddr].sub(realAmount);

        return sharesRemoved;
    }

    function pause() external onlyGov {
        _pause();
    }

    function unpause() external onlyGov {
        _unpause();
    }

    function setDevFundFee(uint256 _devFundFee) public onlyGov {
        require(_devFundFee <= devFundFeeUL, "too high");
        devFundFee = _devFundFee;
    }

    function setBurnedBoboRate(uint256 _burnedBOBORate) public onlyGov {
        require(_burnedBOBORate <= burnedBOBORateUL, "too high");
        burnedBOBORate = _burnedBOBORate;
    }

    function setGov(address _govAddress) public onlyGov {
        govAddress = _govAddress;
    }

    function setDevFundAddr(address _devFundAddr) public onlyGov {
        devFundAddr = _devFundAddr;
    }
    
    function addFarmToken(address _addToken) public onlyGov returns (bool) {
        return EnumerableSet.add(allowedFarmTokenSet, _addToken);
    }

    function delFarmToken(address _delToken) public onlyGov returns (bool) {
        return EnumerableSet.remove(allowedFarmTokenSet, _delToken);
    }

    function getFarmTokenLength() public view returns (uint256) {
        return EnumerableSet.length(allowedFarmTokenSet);
    }

    function isFarmToken(address _farmToken) public view returns (bool) {
        return EnumerableSet.contains(allowedFarmTokenSet, _farmToken);
    }

    function getFarmToken(uint256 _index) public view onlyGov returns (address){
        require(_index <= getFarmTokenLength() - 1, "StatMdxCake: index out of bounds");
        return EnumerableSet.at(allowedFarmTokenSet, _index);
    }
}