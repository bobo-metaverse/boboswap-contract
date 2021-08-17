// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../common/BasicStruct.sol";

contract EXManager is Ownable {
    using SafeMath for uint256;

    address public constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address public constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant swapFactory = 0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32;      // quickswap

    uint256 constant public vipBaseline = 10;
    mapping(address => uint256) public usableTradePointsMap;  // 用户剩余可用的点卡金额，手续费可由此出
    
    uint256 public constant FACTOR = 1e8;
    uint256 public feePercent = 5;
    uint256 constant public BasePercent = 10000;
    uint256 public maxFreePointPerAccount = 10;
    uint256 public minDepositValue = 1e6;       // 充值点卡时的最小金额U
    uint256 public maxNumberPerAMMSwap = 10;    // 一次最多可成交的AMM订单数
    address public feeEarnedContract;           // 项目方抽成资金需打入此合约中，此合约可关联矿池
    mapping(address => bool) public _auth;
    mapping(address => uint256) public accountFreePointMap;   // 账号免手续费交易次数，累加
    mapping(address => uint256) public tokenMinAmountMap;     // 一次交易最小金额
    mapping(address => address) public tokenAggregatorMap;    // token对应的chainlink聚合器合约地址
    uint256 public stopFreeBlockNum;

    address public boboToken;
    uint256 public maxBoboTokenAmount;  // 至少拥有此数量的Bobo可为手续费打五折，至少拥有其十分之一的Bobo才开始打折（9折）

    modifier onlyAuth {
        require(_auth[msg.sender], "no permission");
        _;
    }
    
    constructor (address _boboToken) public {
        usableTradePointsMap[msg.sender] = 10000;
        stopFreeBlockNum = block.number + 300000;
        boboToken = _boboToken;
    }
    
    function addAuth(address _addr) public onlyOwner {
        _auth[_addr] = true;
    }

    function removeAuth(address _addr) public onlyOwner {
        _auth[_addr] = false;
    }

    function setMaxBoboTokenAmount(uint256 _maxBoboTokenAmount) public onlyOwner {
        maxBoboTokenAmount = _maxBoboTokenAmount;
    }

    // 根据Bobo持有数量获取折扣比例，最大50%，最小5%
    function getScalePercent(address _userAddr) public {
        uint256 boboAmount = ERC20(boboToken).balanceOf(_userAddr);
        if (boboAmount < _maxBoboTokenAmount.div(10)) return 10000;

        if (boboAmount > _maxBoboTokenAmount.div(10)) boboAmount = _maxBoboTokenAmount;

        return 10000 - boboAmount.mul(5000).div(_maxBoboTokenAmount);
    }
    
    function setTokenMinAmount(address _tokenAddr, uint256 _minAmount) public onlyOwner {
        tokenMinAmountMap[_tokenAddr] = _minAmount;
    }
    
    function setMaxNumberPerAMMSwap(uint256 _maxNumber) public onlyOwner {
        maxNumberPerAMMSwap = _maxNumber;
    }
    
    function setFeeEarnedContract(address _feeEarnedContract) public onlyOwner {
        uint256 size;
        assembly {
            size := extcodesize(_feeEarnedContract)
        }
        require(size > 0, "EXManager: Only support contract address.");
        feeEarnedContract = _feeEarnedContract;
    }
    
    // 充值平台币，购买点数，需要按整数充值
    function buyTradePoints(uint256 _usdtAmount) public {
        require(_usdtAmount >= minDepositValue, "EXManager: USDT amount must be bigger than minDepositValue.");
        ERC20(USDT).transferFrom(msg.sender, address(this), _usdtAmount);
        usableTradePointsMap[msg.sender] = usableTradePointsMap[msg.sender].add(_usdtAmount);
    }

    function transferTradePoints(address _userAddr, uint256 _transferAmount) public {
        require(usableTradePointsMap[msg.sender] >= _transferAmount, "EXManager: your left trade points must be bigger than _transferAmount.");

        usableTradePointsMap[msg.sender] = usableTradePointsMap[msg.sender].sub(_transferAmount);
        usableTradePointsMap[_userAddr] = usableTradePointsMap[_userAddr].add(_transferAmount);
    }

    // 消耗点卡
    // 在到达区块(区块号为stopFreeBlockNum)之前，前十次(maxFreePointPerAccount)交易免交易费
    function deductTradeFee(address _userAddr, address _token, uint256 _amountIn) public onlyAuth returns(uint256) {
        if (accountFreePointMap[_userAddr] < maxFreePointPerAccount && block.number < stopFreeBlockNum) {
            accountFreePointMap[_userAddr]++;
            return true;
        }

        uint256 usdtDecimals = ERC20(USDT).decimals();
        uint256 tokenDecimals = ERC20(_token).decimals();
        uint256 tokenPrice = getTokenPrice(_token);  // *10^8
        
        uint256 scalePercent = getScalePercent(_userAddr);  // 根据用户当前持有的BOBO数量获取折扣比例
        uint256 tokenAmount4Fee = _amountIn.mul(feePercent).mul(scalePercent).div(BasePercent * 2);

        uint256 usdtAmount4Fee = tokenPrice.mul(tokenAmount4Fee).div(10**FACTOR.add(tokenDecimals).sub(usdtDecimals));
        if (usableTradePointsMap[_userAddr] >= usdtAmount4Fee) {
            usableTradePointsMap[_userAddr] = usableTradePointsMap[_userAddr].sub(usdtAmount4Fee);
            return 0;
        } else {
            return tokenAmount4Fee;
        }
    }

    function evaluateDeductedAmountIn(address _userAddr, address _token, uint256 _amountIn) view public returns(uint256, uint256) {
        uint256 usdtDecimals = ERC20(USDT).decimals();
        uint256 tokenDecimals = ERC20(_token).decimals();
        uint256 tokenPrice = getTokenPrice(_token);  // *10^8
        
        uint256 scalePercent = getScalePercent(_userAddr);  // 根据用户当前持有的BOBO数量获取折扣比例
        uint256 tokenAmount4Fee = _amountIn.mul(feePercent).mul(scalePercent).div(BasePercent * 2);

        uint256 usdtAmount4Fee = tokenPrice.mul(tokenAmount4Fee).div(10**FACTOR.add(tokenDecimals).sub(usdtDecimals));
        if (usableTradePointsMap[_userAddr] >= usdtAmount4Fee) {
            return (0, usdtAmount4Fee);
        } else {
            return (tokenAmount4Fee, usdtAmount4Fee);
        }
    }

    function getTokenPrice(address _token) public view returns(uint256) {
        uint256 priceOnAMM = getTokenPriceOnAMM(_token);
        uint256 priceOnChainlink = getTokenPriceOnChainlink(_token);
        if(priceOnChainlink == 0) return priceOnAMM;

        uint256 gap = 0;
        if (priceOnAMM > priceOnChainlink) {
            gap = priceOnAMM.sub(priceOnChainlink).mul(1000).div(priceOnChainlink);
        } else {
            gap = priceOnChainlink.sub(priceOnAMM).mul(1000).div(priceOnAMM);
        }
        require(gap <= 100, "EXManager: the price gap between chainlink and AMM is large than 10%.");
        return priceOnChainlink;
    }

    function getTokenPriceOnAMM(address _token) public view returns(uint256) {
        if (_token == USDT || _token == USDC) return 1;

        (address token0, address token1) = USDT < _token ? (USDT, _token) : (_token, USDT);
        address pairAddr = ICommonFactory(swapFactory).getPair(token0, token1);
        (uint256 reserveA, uint256 reserveB,) = ICommonPair(pairAddr).getReserves();
        uint256 decimalsGap = ERC20(_token).decimals() - ERC20(USDT).decimals();
        // 为匹配chainlink，此处的价格也乘上10^8（FACTOR）
        return token0 == USDT ? reserveA.mul(FACTOR).mul(decimalsGap).div(reserveB) : reserveB.mul(FACTOR).mul(decimalsGap).div(reserveA);
    }
    
    // chainlink返回的价格是U，但乘上了10^8
    function getTokenPriceOnChainlink() public view returns(uint256) {
        if (_token == USDT || _token == USDC) return 1;

        address aggregatorAddr = tokenAggregatorMap[_token];
        if (aggregatorAddr == address(0)) return 0;

        AggregatorV3Interface priceFeed = AggregatorV3Interface(aggregatorAddr);
        (, int price,,,) = priceFeed.latestRoundData();
        return uint256(price);
    }
    
    function setStopFreeBlockNum(uint256 _blockNum) public onlyOwner {
        stopFreeBlockNum = _blockNum;
    }

    function setFeePercent(uint256 _feePercent) public onlyOwner {
        feePercent = _feePercent;
    }
    
    function withdraw(address _token, address _receiver) public onlyOwner {
        uint256 amount = ERC20(_token).balanceOf(address(this));
        ERC20(_token).transfer(_receiver, amount);
    }
    
    function addAggregtor(address _token, address _aggregator) public onlyOwner {
        tokenAggregatorMap[_token] = _aggregator;
    }
}