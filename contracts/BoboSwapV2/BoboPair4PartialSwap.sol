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
    function routerWhiteList(address _router) view external returns(bool);
}

interface IBoboFarmer {
    function deposit(address _tokenAddr, address _userAddr, uint256 _amount) external;
    function withdraw(address _tokenAddr, address _userAddr, uint256 _amount) external;

    function pendingBOBO(address _tokenAddr, address _user) external view returns (uint256);
    function stakedWantTokens(address _tokenAddr, address _user) external view returns (uint256);
    function tokenPidMap(address _tokenAddr) external view returns (uint256);
}

interface IBoboRouter {
    function getBaseAmountOut(address inToken, address outToken, uint256 amountIn) external view returns(uint256 amountOut);
    function swap(address _inToken, address _outToken, uint256 _amountIn, uint256 _minAmountOut, address _orderOwner) external;  // uint256 totalAmountOut, 
}

contract BoboPairV2 is MixinAuthorizable, OrderStore, ReentrancyGuard {
    using SafeMath for uint256;
    
    uint256 public constant BasePercent = 10000;
    uint256 public constant BaseAmountIn = 1e9;
    
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
    function initialize(address _quoteToken, address _baseToken, address _authAddr, address _boboFarmer, address _orderNFT) external onlyOwner {
        quoteToken = _quoteToken;
        baseToken = _baseToken;
        quoteTokenDecimals = ERC20(quoteToken).decimals();
        baseTokenDecimals = ERC20(baseToken).decimals();
        addAuthorized(_authAddr);
        boboFarmer = IBoboFarmer(_boboFarmer);
        orderNFT = IOrderNFT(_orderNFT);
    }
    
    function setExManager(address _exManager) external onlyAuthorized {
        exManager = IExchangeManager(_exManager);
    }

    function getTokens() view public returns(address, address) {
        return (quoteToken, baseToken);
    }
    
    // 限价单
    // _spotPrice: 以U为单位，如1000000表示下单价格为1U
    function addLimitedOrder(bool _bBuyQuoteToken, uint256 _spotPrice, uint256 _amountIn, uint256 _slippagePercent) public nonReentrant {
        require(_slippagePercent <= 1000, "BoboPair: slippage MUST <= 1000(10%)");
        
        uint256 minOutAmount = 0;
        if (_bBuyQuoteToken) {
            minOutAmount = _amountIn.mul(10**quoteTokenDecimals).div(_spotPrice).mul(BasePercent - _slippagePercent).div(BasePercent);
        } else {
            minOutAmount = _amountIn.mul(_spotPrice).div(10**quoteTokenDecimals).mul(BasePercent - _slippagePercent).div(BasePercent);
        }
        (address inToken, ) = _bBuyQuoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        // 判断是否满足最小下单量
        require(_amountIn >= exManager.tokenMinAmountMap(inToken), "BoboPair: inAmount MUST larger than min amount.");
        
        addOrder(_bBuyQuoteToken, _spotPrice, _amountIn, minOutAmount);
        
        ERC20(inToken).transferFrom(msg.sender, address(this), _amountIn);
        if (boboFarmer.tokenPidMap(inToken) > 0) {
            ERC20(inToken).approve(address(boboFarmer), _amountIn);
            boboFarmer.deposit(inToken, msg.sender, _amountIn);
        }
    }
    
    // 市价单
    function addMarketOrder(address _boboRouter, bool _bBuyQuoteToken, uint256 _amountIn, uint256 _minOutAmount) public nonReentrant {
        (address inToken, address outToken) = _bBuyQuoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        require(_minOutAmount >= 0, "BoboPair: _minOutAmount should be > 0.");
        require(_amountIn >= exManager.tokenMinAmountMap(inToken), "BoboPair: inAmount MUST larger than min amount.");
        require(exManager.routerWhiteList(_boboRouter), "BoboPair: router NOT in whitelist!");
        
        // 扣手续费
        uint256 deductAmount = exManager.deductTradeFee(msg.sender, inToken, _amountIn);
        if (deductAmount > 0) {
            ERC20(inToken).transferFrom(msg.sender, address(exManager), deductAmount);
        }
        _amountIn = _amountIn.sub(deductAmount);

        uint256 spotPrice = _bBuyQuoteToken ? _amountIn.mul(10**quoteTokenDecimals).div(_minOutAmount) : _minOutAmount.mul(10**quoteTokenDecimals).div(_amountIn);
        uint256 orderId = addOrder(_bBuyQuoteToken, spotPrice, _amountIn, _minOutAmount);
        NFTInfo memory orderInfo = orderNFT.getOrderInfo(orderId);  
        swap(_boboRouter, orderInfo, inToken, outToken, _amountIn, _minOutAmount, msg.sender, false);
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
        uint256 amountOut = IBoboRouter(_boboRouter).getBaseAmountOut(baseToken, quoteToken, BaseAmountIn);
        uint256 spotPrice = BaseAmountIn.mul(10**quoteTokenDecimals).div(amountOut);
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

    function swap(address _boboRouter, NFTInfo storage _orderInfo, 
                  address _inToken, address _outToken, 
                  uint256 _amountIn, uint256 _minAmountOut, bool _bInner) private returns(uint256) {
        if (!_bInner) {
            ERC20(_inToken).transferFrom(msg.sender, address(this), _amountIn);
        }

        uint256 orderId = _orderInfo.id;
        address orderOwner= _orderInfo.owner;

        uint256 outTokenAmount = ERC20(_outToken).balanceOf(address(this));

        ERC20(_inToken).approve(_boboRouter, _amountIn);
        IBoboRouter(_boboRouter).swap(_inToken, _outToken, _amountIn, _minAmountOut, orderOwner);
        uint256 totalAmountOut = ERC20(_outToken).balanceOf(address(this)).sub(outTokenAmount);   // 兑换出来的outToken数量
        require(totalAmountOut >= _minAmountOut, "BoboPair: the amount of outToken is NOT enough!");

        if(_orderInfo.inAmount == _amountIn) {   // 表示本订单的所有挂单金额都被吃完了
            ERC20(_outToken).transfer(orderOwner, totalAmountOut);
            setDealedOrder(orderId, totalAmountOut);
        } else {
            uint256 childOrderId = addOrder(orderId, _orderInfo.bBuyQuoteToken, _orderInfo.spotPrice, _amountIn, minOutAmount);
            setDealedOrder(childOrderId, totalAmountOut);
            _orderInfo.inAmount = _orderInfo.inAmount.sub(_amountIn);
            _orderInfo.minOutAmount = _orderInfo.minOutAmount.sub(totalAmountOut);
        }
        
        makeStatistic(_inToken == baseToken ? _amountIn : totalAmountOut);
        return totalAmountOut;
    }

    // taker
    function swapExactTokensForTokens(address _boboRouter, uint256 _orderId, uint256 _amountIn) public nonReentrant {  
        require(exManager.routerWhiteList(_boboRouter), "BoboPair: router NOT in whitelist!");                 
        NFTInfo storage orderInfo = orderNFT.getOrderInfo(_orderId);  
        require(orderInfo.status == OrderStatus.Hanging, "BoboPair: order's status is NOT hanging!");
        require(orderInfo.inAmount >= _amountIn, "BoboPair: order does NOT have enough amount of inToken.");
        (address inToken, address outToken) = orderInfo.bBuyQuoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        
        uint256 deductAmount = exManager.deductTradeFee(orderInfo.owner, inToken, _amountIn);
        
        if (boboFarmer.tokenPidMap(inToken) > 0) {
            boboFarmer.withdraw(inToken, orderInfo.owner, amountIn);
        }
        uint256 amountIn = _amountIn.sub(deductAmount);
        if (deductAmount > 0) {
            ERC20(inToken).transferFrom(address(this), address(exManager), deductAmount);
        }
        uint256 minAmountOut = orderInfo.minOutAmount.mul(_amountIn).div(orderInfo.inAmount);  // 根据amountIn计算出等比例的minAmountOut
        swap(_boboRouter, orderInfo, inToken, outToken, amountIn, minAmountOut, true);
    }    

    // _outTokenAmountSwapIn: 指定订单需要获得的outToken数量
    // 通过_outTokenAmountSwapIn以及订单情况，可计算出外部可获得多少inToken，并transfer出去
    // maker支付手续费，taker免手续费
    function swapTokensForExactTokens(uint256 _orderId, uint256 _outTokenAmountSwapIn) public {
        NFTInfo storage orderInfo = orderNFT.getOrderInfo(_orderId); 
        require(orderInfo.status == OrderStatus.Hanging, "BoboPair: order's status is NOT hanging!");
        (address inToken, address outToken) = orderInfo.bBuyQuoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        
        // 计算出本订单最多可接受的outToken数量，此处已扣除maker需要支付的手续费
        (uint256 maxDeductAmount, ) = exManager.evaluateDeductedAmountIn(orderInfo.owner, inToken, orderInfo.inAmount);
        uint256 maxAmountSwapOut = orderInfo.bBuyQuoteToken ? orderInfo.inAmount.sub(maxDeductAmount).mul(10**quoteTokenDecimals).div(orderInfo.spotPrice) 
                                                            : orderInfo.inAmount.sub(maxDeductAmount).mul(orderInfo.spotPrice).div(10**quoteTokenDecimals);        
        _outTokenAmountSwapIn = _outTokenAmountSwapIn > maxAmountSwapOut ? maxAmountSwapOut : _outTokenAmountSwapIn;

        // 使用maxAmountSwapOut，而不是orderInfo.minOutAmount，可以使挂单者获得不带滑点的收益
        uint256 inTokenAmountSwapOut = _outTokenAmountSwapIn.mul(orderInfo.inAmount).div(maxAmountSwapOut);   

        uint256 deductAmount = exManager.deductTradeFee(orderInfo.owner, inToken, inTokenAmountSwapOut);
        
        uint256 amountIn = inTokenAmountSwapOut.add(deductAmount);   // 此处需要加上手续费，从订单owner的amountIn里面扣除

        if (boboFarmer.tokenPidMap(inToken) > 0) {
            boboFarmer.withdraw(inToken, orderInfo.owner, amountIn);
        }
        if (deductAmount > 0) {
            ERC20(inToken).transferFrom(address(this), address(exManager), deductAmount);
            amountIn = amountIn.sub(deductAmount);
        }

        // 将outToken给订单owner
        ERC20(outToken).transferFrom(msg.sender, orderInfo.owner, _outTokenAmountSwapIn);

        // 将inToken转给msg.sender
        ERC20(inToken).transfer(msg.sender, amountIn);

        if(_orderInfo.inAmount == inTokenAmountSwapOut) {   // 表示本订单的所有挂单金额都被吃完了
            setDealedOrder(orderId, _outTokenAmountSwapIn);
        } else {
            uint256 childOrderId = addOrder(orderId, orderInfo.bBuyQuoteToken, orderInfo.spotPrice, amountIn, _outTokenAmountSwapIn);
            setDealedOrder(childOrderId, _outTokenAmountSwapIn);
            orderInfo.inAmount = orderInfo.inAmount.sub(amountIn);
            orderInfo.minOutAmount = orderInfo.minOutAmount.sub(_outTokenAmountSwapIn);
        }
        
        makeStatistic(_inToken == baseToken ? _amountIn : totalAmountOut);
        return totalAmountOut;
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