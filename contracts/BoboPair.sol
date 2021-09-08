// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./common/OrderStore.sol";
import "./common/MixinAuthorizable.sol";

interface IExchangeManager {
    function evaluateDeductedAmountIn(address _userAddr, address _token, uint256 _amountIn) view external returns(uint256, uint256);
    function deductTradeFee(address _userAddr, address _token, uint256 _amountIn) external returns(uint256);
    function feeEarnedContract() view external returns(uint256);
    function maxOrderNumberPerMatch() view external returns(uint256);
    function tokenInvestRateMap(address _tokenAddr) view external returns(uint256);
    function tokenMinAmountMap(address _tokenAddr) view external returns(uint256);
}

interface IBoboFarmer {
    function deposit(address _tokenAddr, address _userAddr, uint256 _amount) external;
    function withdraw(address _tokenAddr, address _userAddr, uint256 _amount) external;

    function pendingBOBO(address _tokenAddr, address _user) external view returns (uint256);
    function stakedWantTokens(address _tokenAddr, address _user) external view returns (uint256);
    function tokenPidMap(address _tokenAddr) external view returns (uint256);
}


contract BoboPair is MixinAuthorizable, OrderStore, ReentrancyGuard {
    using SafeMath for uint256;
    
    uint256 public constant BasePercent = 10000;
    uint256 public constant BasePriceAmount = 1e9;
    
    IExchangeManager public exManager;
    IBoboFarmer public boboFarmer;
    
    address public factory;
    address public quoteToken;
    address public baseToken;
    uint256 public quoteTokenDecimals;
    uint256 public baseTokenDecimals;
    
    
    uint256 public constant OneDaySeconds = 24 * 3600;
    uint256 public startTime;
    uint256 public lastRecordTime;
    uint256 public volumnOf24Hours;
    uint256 public totalVolumn;
    uint256[] public volumnList;

    event SwapSuccess(address indexed owner, address indexed spender, uint value);
    
    constructor () public OrderStore() {  
        factory = msg.sender;
        addAuthorized(msg.sender);
        startTime = now;
        lastRecordTime = startTime;
    }

    // called once by the factory at time of deployment
    function initialize(address _quoteToken, address _baseToken, address _authAddr, address _boboFarmer, address _orderNFT, address _orderDetailNFT) external onlyOwner {
        quoteToken = _quoteToken;
        baseToken = _baseToken;
        quoteTokenDecimals = ERC20(quoteToken).decimals();
        baseTokenDecimals = ERC20(baseToken).decimals();
        addAuthorized(_authAddr);
        boboFarmer = IBoboFarmer(_boboFarmer);
        orderNFT = IOrderNFT(_orderNFT);
        orderDetailNFT = IOrderDetailNFT(_orderDetailNFT);
    }
    
    function setExManager(address _exManager) external onlyAuthorized {
        exManager = IExchangeManager(_exManager);
    }

    function getTokens() view public returns(address, address) {
        return (quoteToken, baseToken);
    }
    
    // 限价单
    // _spotPrice: 以U为单位，如1000000表示下单价格为1U
    function addLimitedOrder(address _boboRouter, bool _bBuyQuoteToken, uint256 _spotPrice, uint256 _amountIn, uint256 _slippagePercent) public nonReentrant {
        require(_slippagePercent <= 1000, "BoboPair: slippage MUST <= 1000(10%)");
        
        uint256 minOutAmount = 0;
        if (_bBuyQuoteToken) {
            minOutAmount = _amountIn.mul(10**quoteTokenDecimals).div(_spotPrice).mul(BasePercent - _slippagePercent).div(BasePercent);
        } else {
            minOutAmount = _amountIn.mul(_spotPrice).div(10**quoteTokenDecimals).mul(BasePercent - _slippagePercent).div(BasePercent);
        }
        uint256 orderId = addOrder(_bBuyQuoteToken, _spotPrice, _amountIn, minOutAmount);
        
        (address inToken, address outToken) = _bBuyQuoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        // 判断是否满足最小下单量
        require(_amountIn >= exManager.tokenMinAmountMap(inToken), "BoboPair: inAmount MUST larger than min amount.");

        // 评估手续费
        (uint256 deductedAmountIn, ) = exManager.evaluateDeductedAmountIn(msg.sender, inToken, _amountIn);
        (, ResultInfo memory bestSwapInfo) = IBoboRouter(_boboRouter).getBestSwapPath(inToken, outToken, _amountIn.sub(deductedAmountIn));
        
        // 下限价单时满足交易条件
        if (bestSwapInfo.totalAmountOut >= minOutAmount) {  
            // 扣除手续费
            uint256 deductAmount = exManager.deductTradeFee(msg.sender, inToken, _amountIn);
            if (deductAmount > 0) {
                ERC20(inToken).transferFrom(msg.sender, address(exManager), deductAmount);
            }
            uint256 amountIn = _amountIn.sub(deductAmount);
            swap(_boboRouter, orderId, bestSwapInfo, inToken, outToken, amountIn, false);
        } else {
            ERC20(inToken).transferFrom(msg.sender, address(this), _amountIn);
            if (boboFarmer.tokenPidMap(inToken) > 0) {
                ERC20(inToken).approve(address(boboFarmer), _amountIn);
                boboFarmer.deposit(inToken, msg.sender, _amountIn);
            }
        }
    }
    
    // 市价单
    function addMarketOrder(address _boboRouter, bool _bBuyQuoteToken, uint256 _amountIn, uint256 _minOutAmount) public nonReentrant {
        (address inToken, address outToken) = _bBuyQuoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        require(_amountIn >= exManager.tokenMinAmountMap(inToken), "BoboPair: inAmount MUST larger than min amount.");

        uint256 deductAmount = exManager.deductTradeFee(msg.sender, inToken, _amountIn);
        if (deductAmount > 0) {
            ERC20(inToken).transferFrom(msg.sender, address(exManager), deductAmount);
        }
        _amountIn = _amountIn.sub(deductAmount);

        (, ResultInfo memory bestSwapInfo) = IBoboRouter(_boboRouter).getBestSwapPath(inToken, outToken, _amountIn);
        require(bestSwapInfo.totalAmountOut >= _minOutAmount, "BoboPair: can NOT satisfy your trade request.");
        // 下限价单时满足交易条件
        if (_minOutAmount == 0) 
            _minOutAmount = bestSwapInfo.totalAmountOut;
        uint256 spotPrice = _bBuyQuoteToken ? _amountIn.mul(10**quoteTokenDecimals).div(_minOutAmount) : _minOutAmount.mul(10**quoteTokenDecimals).div(_amountIn);
        uint256 orderId = addOrder(_bBuyQuoteToken, spotPrice, _amountIn, _minOutAmount);
        swap(_boboRouter, orderId, bestSwapInfo, inToken, outToken, _amountIn, false);
    }
       
    function makeStatistic(uint256 _amount) private {
        totalVolumn = totalVolumn.add(_amount);
        
        uint256 lastPeriod = lastRecordTime.sub(startTime).div(OneDaySeconds);
        uint256 currentPeriod = (now - startTime).div(OneDaySeconds);
        if (currentPeriod > lastPeriod) {
            volumnList.push(volumnOf24Hours);
            volumnOf24Hours = 0;
        }
        volumnOf24Hours = volumnOf24Hours.add(_amount);
        lastRecordTime = now;
    }
    
    function getCurrentPrice(address _boboRouter) view public returns(uint256) {
        (, ResultInfo memory bestSwapInfo) = IBoboRouter(_boboRouter).getBestSwapPath(baseToken, quoteToken, BasePriceAmount);
        uint256 amountOut = bestSwapInfo.totalAmountOut;
        uint256 spotPrice = BasePriceAmount.mul(10**quoteTokenDecimals).div(amountOut);
        return spotPrice;
    }

    function getTotalHangingTokenAmount(address _userAddr) view public returns(uint256 baseTokenAmount, uint256 quoteTokenAmount) {
        uint256 length = getUserHangingOrderNumber(_userAddr);
        for (uint256 i = 0; i < length; i++) {
            uint256 orderId = getUserHangingOrderId(_userAddr, i);
            NFTInfo memory orderInfo = orderNFT.getOrderInfo(orderId); 
            if (orderInfo.bBuyQuoteToken) {
                baseTokenAmount = baseTokenAmount.add(orderInfo.inAmount);
            } else {
                quoteTokenAmount = quoteTokenAmount.add(orderInfo.inAmount);
            }
        }
    }        

    function swap(address _boboRouter, uint256 _orderId, ResultInfo memory _bestSwapInfo, 
                  address _inToken, address _outToken, uint256 _amountIn, bool _bInner) private returns(uint256) {
        if (!_bInner) {
            ERC20(_inToken).transferFrom(msg.sender, address(this), _amountIn);
        }
        ERC20(_inToken).approve(_boboRouter, _amountIn);
        uint256 outTokenAmount = ERC20(_outToken).balanceOf(address(this));
        IBoboRouter(_boboRouter).swap(_bestSwapInfo, _inToken, _outToken, _amountIn, address(this));
        uint256 totalAmountOut = ERC20(_outToken).balanceOf(address(this)).sub(outTokenAmount);

        setAMMDealOrder(_orderId, totalAmountOut);
        
        // NFTInfo memory orderInfo = orderNFT.getOrderInfo(_orderId); 
        // for (uint256 i = 0; i < _bestSwapInfo.swapPools.length && _bestSwapInfo.swapPools[i] != SwapPool.No; i++) {
        //     address[3] memory path = [_inToken, _bestSwapInfo.middleTokens[i], _outToken];
        //     addOrderDetail(orderInfo.owner, 
        //                    _orderId, 
        //                    _bestSwapInfo.partialAmountIns[i], 
        //                    partialAmountOuts[i], 
        //                    _bestSwapInfo.swapPools[i],
        //                    path);
        // }
        makeStatistic(_inToken == baseToken ? _amountIn : totalAmountOut);
        return totalAmountOut;
    }

    // _swapPools: 聚合交易时具体的AMM池子, Mdex, Pancake, OneInch, Uniswap, SushiSwap, Dodo, QuickSwap
    // _middleTokens: 两种代币在兑换过程中的中间代币，如=address(0)，表示无中间代币
    // _partialAmountIns: 每笔交易投入的inToken的数量，注意它们的和要小于用户初始投入的金额（因为有手续费要扣除）
    //   (1) 在通过BoboRouter.getBestSwapPath获取最佳交易路劲之前，需要先通过EXManager.evaluateDeductedAmountIn获取用户需要扣除的手续费，之后再在getBestSwapPath中传入amountIn
    //   (2) 通过预付手续费，可以降低交易执行
    function executeSpecifiedOrder(address _boboRouter, uint256 _orderId, 
                                   SwapPool[] memory _swapPools, address[] memory _middleTokens, uint256[] memory _partialAmountIns) public nonReentrant {                                       
        NFTInfo memory orderInfo = orderNFT.getOrderInfo(_orderId); 
        (address inToken, address outToken) = orderInfo.bBuyQuoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        
        uint256 deductAmount = exManager.deductTradeFee(orderInfo.owner, inToken, orderInfo.inAmount);
        
        uint256 amountIn = orderInfo.inAmount.sub(deductAmount);
        if (boboFarmer.tokenPidMap(inToken) > 0) {
            boboFarmer.withdraw(inToken, orderInfo.owner, amountIn);
        }
        if (deductAmount > 0) {
            ERC20(inToken).transferFrom(address(this), address(exManager), deductAmount);
        }
        ResultInfo memory resultInfo;
        resultInfo.swapPools = _swapPools;
        resultInfo.middleTokens = _middleTokens;
        resultInfo.partialAmountIns = _partialAmountIns;
        resultInfo.partialAmountOuts = new uint256[](4);

        uint256 amountOut = swap(_boboRouter, _orderId, resultInfo, inToken, outToken, amountIn, true);
        require(amountOut >= orderInfo.minOutAmount, "BoboPair: amountOut NOT enough");
    }    
    
    function cancelOrder(uint256 _orderId) public returns(bool) {
        setManualCancelOrder(_orderId); 

        NFTInfo memory orderInfo = orderNFT.getOrderInfo(_orderId); 
        address inToken = orderInfo.bBuyQuoteToken ? baseToken : quoteToken;
        if (boboFarmer.tokenPidMap(inToken) > 0) {
            boboFarmer.withdraw(inToken, orderInfo.owner, orderInfo.inAmount);
            ERC20(inToken).transfer(orderInfo.owner, orderInfo.inAmount);
        } else {
            ERC20(inToken).transfer(orderInfo.owner, orderInfo.inAmount);
        }
    }
    
}