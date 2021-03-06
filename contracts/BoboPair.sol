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

contract BoboPair is MixinAuthorizable, OrderStore, ReentrancyGuard {
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
    
    // ?????????
    // _spotPrice: ???U???????????????1000000?????????????????????1U
    function addLimitedOrder(bool _bBuyQuoteToken, uint256 _spotPrice, uint256 _amountIn, uint256 _slippagePercent) public nonReentrant {
        require(_slippagePercent <= 1000, "BoboPair: slippage MUST <= 1000(10%)");
        
        uint256 minOutAmount = 0;
        if (_bBuyQuoteToken) {
            minOutAmount = _amountIn.mul(10**quoteTokenDecimals).div(_spotPrice).mul(BasePercent - _slippagePercent).div(BasePercent);
        } else {
            minOutAmount = _amountIn.mul(_spotPrice).div(10**quoteTokenDecimals).mul(BasePercent - _slippagePercent).div(BasePercent);
        }
        (address inToken, ) = _bBuyQuoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        // ?????????????????????????????????
        require(_amountIn >= exManager.tokenMinAmountMap(inToken), "BoboPair: inAmount MUST larger than min amount.");
        
        addOrder(_bBuyQuoteToken, _spotPrice, _amountIn, minOutAmount);
        
        ERC20(inToken).transferFrom(msg.sender, address(this), _amountIn);
        if (boboFarmer.tokenPidMap(inToken) > 0) {
            ERC20(inToken).approve(address(boboFarmer), _amountIn);
            boboFarmer.deposit(inToken, msg.sender, _amountIn);
        }
    }
    
    // ?????????
    function addMarketOrder(address _boboRouter, bool _bBuyQuoteToken, uint256 _amountIn, uint256 _minOutAmount) public nonReentrant {
        (address inToken, address outToken) = _bBuyQuoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        require(_minOutAmount >= 0, "BoboPair: _minOutAmount should be > 0.");
        require(_amountIn >= exManager.tokenMinAmountMap(inToken), "BoboPair: inAmount MUST larger than min amount.");
        require(exManager.routerWhiteList(_boboRouter), "BoboPair: router NOT in whitelist!");
        
        // ????????????
        uint256 deductAmount = exManager.deductTradeFee(msg.sender, inToken, _amountIn);
        if (deductAmount > 0) {
            ERC20(inToken).transferFrom(msg.sender, address(exManager), deductAmount);
        }
        _amountIn = _amountIn.sub(deductAmount);

        uint256 spotPrice = _bBuyQuoteToken ? _amountIn.mul(10**quoteTokenDecimals).div(_minOutAmount) : _minOutAmount.mul(10**quoteTokenDecimals).div(_amountIn);
        uint256 orderId = addOrder(_bBuyQuoteToken, spotPrice, _amountIn, _minOutAmount);
        swap(_boboRouter, orderId, inToken, outToken, _amountIn, _minOutAmount, msg.sender, false);
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

    function swap(address _boboRouter, uint256 _orderId, 
                  address _inToken, address _outToken, 
                  uint256 _amountIn, uint256 _minAmountOut, 
                  address _orderOwner, bool _bInner) private returns(uint256) {
        if (!_bInner) {
            ERC20(_inToken).transferFrom(msg.sender, address(this), _amountIn);
        }

        uint256 outTokenAmount = ERC20(_outToken).balanceOf(address(this));

        ERC20(_inToken).approve(_boboRouter, _amountIn);
        IBoboRouter(_boboRouter).swap(_inToken, _outToken, _amountIn, _minAmountOut, _orderOwner);
        uint256 totalAmountOut = ERC20(_outToken).balanceOf(address(this)).sub(outTokenAmount);   // ???????????????outToken??????
        require(totalAmountOut >= _minAmountOut, "BoboPair: the amount of outToken is NOT enough!");
        ERC20(_outToken).transfer(_orderOwner, totalAmountOut);

        setAMMDealOrder(_orderId, totalAmountOut);
        makeStatistic(_inToken == baseToken ? _amountIn : totalAmountOut);
        return totalAmountOut;
    }

    // taker
    function executeSpecifiedOrder(address _boboRouter, uint256 _orderId) public nonReentrant {  
        require(exManager.routerWhiteList(_boboRouter), "BoboPair: router NOT in whitelist!");                 
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
        
        swap(_boboRouter, _orderId, inToken, outToken, amountIn, orderInfo.minOutAmount, orderInfo.owner, true);
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