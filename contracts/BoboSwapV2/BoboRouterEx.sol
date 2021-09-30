// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
        
import "../common/BasicStruct.sol";
import "../SwapInterfaces.sol";

interface IBoboRouter {
    function getBaseAmountOut(address inToken, address outToken, uint256 amountIn) external view returns(uint256 amountOut);
    function swap(address _inToken, address _outToken, uint256 _amountIn, uint256 _minAmountOut, address _orderOwner) external;  // uint256 totalAmountOut, 
}

interface IBoboPair {
    function baseToken() view external returns(address);
    function executeSpecifiedOrder(address _boboRouter, uint256 _orderId, uint256 _amountIn) external;
    function getTotalOrderNumber(bool _bBuy) view external returns(uint256);
    function getHeaderOrderIndex(bool _bBuy) view external returns(bool exist, uint256 index);
    function getOrderInfos(bool _bBuy, uint256 _fromIndex, uint256 _toIndex) view external returns(OrderInfo[] memory orderInfos);
    function getMaxAmountSwapOutToken(uint256 _orderId) view external returns(uint256);
    function swapTokensForExactTokens(uint256 _orderId, uint256 _outTokenAmountSwapIn) external returns(uint256);
}

interface IBoboFactory {
    function getPair(address tokenA, address tokenB) view external returns(address);
}

contract BoboRouterEx is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    IBoboRouter public boboRouter;
    IBoboFactory public boboFactory;

    constructor(address _boboFactory, address _boboRouter) public {
        boboFactory = IBoboFactory(_boboFactory);
        boboRouter = IBoboRouter(_boboRouter);
    }

    function getBaseAmountOut(address inToken, address outToken, uint256 amountIn) public view returns(uint256 amountOut) {

    }

    // 用户下市价单时，从pair调用到此接口，此接口先处理挂单，如还有剩余token未成交，再调用BoboRouter接口，让其同AMM进行交易
    function swap(address _inToken, address _outToken, uint256 _amountIn, uint256 _maxAmountOut, uint256 _minAmountOut, address _orderOwner) public {
        IERC20(_inToken).transferFrom(msg.sender, address(this), _amountIn);
        uint256 preInTokenBalance = IERC20(_inToken).balanceOf(address(this));

        address boboPairAddr = boboFactory.getPair(_inToken, _outToken);
        IBoboPair boboPair = IBoboPair(boboPairAddr);
        address baseToken = boboPair.baseToken();
        bool bBuyQuoteToken = baseToken == _inToken;   // true: 表示要swap的订单是买单，需要找卖单匹配  false: 表示swap的订单是卖单，需要找卖单匹配
        uint256 quoteTokenDecimals = bBuyQuoteToken ? ERC20(_outToken).decimals() : ERC20(_inToken).decimals();
        uint256 spotPrice = bBuyQuoteToken ? _amountIn.mul(10**quoteTokenDecimals).div(_minOutAmount) 
                                           : _minOutAmount.mul(10**quoteTokenDecimals).div(_amountIn);

        uint256 orderNumber = boboPair.getTotalOrderNumber(!bBuyQuoteToken);
        uint256 step = 1;
        uint256 leftAmountIn = _amountIn;   // 剩余可兑换的资金
        uint256 swappedOutTokenAmount = 0;  // 被兑换出来的资金
        for (uint256 fromIndex = 0; fromIndex < orderNumber; fromIndex += step) {
            uint256 toIndex = fromIndex + step;
            if (toIndex > orderNumber)
                toIndex = orderNumber;

            OrderInfo[] memory orderInfos = getOrderInfos(!bBuyQuoteToken, fromIndex, toIndex);
            OrderInfo memory orderInfo = orderInfos[0];
            uint256 maxOutAmountExpected = boboPair.getMaxOutAmountExpected(orderInfo.id);

            if ((bBuyQuoteToken && spotPrice >= orderInfo.spotPrice) || (!bBuyQuoteToken && spotPrice <= orderInfo.spotPrice)) {  // 匹配价格满足条件的挂单
                uint256 preSwappedOutTokenAmount = IERC20(_outToken).balanceOf(address(this));
                
                if (leftAmountIn >= maxOutAmountExpected) {  // 输入的inToken数量满足卖单所需，可以完全吃掉此订单
                    IERC20(_inToken).approve(address(boboPair), maxOutAmountExpected);
                    boboPair.swapTokensForExactTokens(orderInfo.id, maxOutAmountExpected);
                } else {  // 无法完全吃掉此订单，只能吃一部分
                    IERC20(_inToken).approve(address(boboPair), leftAmountIn);
                    boboPair.swapTokensForExactTokens(orderInfo.id, leftAmountIn);
                }
                
                uint256 newSwappedOutTokenAmount = IERC20(_outToken).balanceOf(address(this));   // 兑换出来的token
                uint256 newInTokenBalance = IERC20(_inToken).balanceOf(address(this));  // 兑换进去的token

                uint256 swappedInTokenBalance = newInTokenBalance.sub(preInTokenBalance);
                uint256 swappedOutTokenBalance = newSwappedOutTokenAmount.sub(preSwappedOutTokenAmount);
                preInTokenBalance = newInTokenBalance;
                leftAmountIn = leftAmountIn.sub(swappedInTokenBalance);
                swappedOutTokenAmount = swappedOutTokenAmount.add(swappedOutTokenBalance);
                if (swappedOutTokenAmount >= _minAmountOut || leftAmountIn == 0) {
                    break;
                }
            } else {
                break;
            }
        }
        // 兑换的token数已满足最低要求
        if (swappedOutTokenAmount >= _minAmountOut) {
            swappedOutTokenAmount = swappedOutTokenAmount > _maxAmountOut ? _maxAmountOut : swappedOutTokenAmount;
            IERC20(_outToken).transfer(msg.sender, swappedOutTokenAmount);
        } else {
            require(leftAmountIn > 0, "BoboRotuerEx: left amountIn should be > 0.");
            IERC20(_inToken).approve(address(boboRouter), leftAmountIn);

            uint256 outTokenAmount = IERC20(_outToken).balanceOf(address(this));
            boboRouter.swap(_inToken, _outToken, leftAmountIn, _minAmountOut.sub(swappedOutTokenAmount), _orderOwner);
            uint256 amountOutByAMM = ERC20(_outToken).balanceOf(address(this)).sub(outTokenAmount); 
            swappedOutTokenAmount = swappedOutTokenAmount.add(amountOutByAMM);
            
            require(swappedOutTokenAmount >= _minAmountOut, "BoboRotuerEx: can NOT take enough out token.");
            swappedOutTokenAmount = swappedOutTokenAmount > _maxAmountOut ? _maxAmountOut : swappedOutTokenAmount;
            IERC20(_outToken).transfer(msg.sender, swappedOutTokenAmount);
        }
    }

    function withdrawToken(address _tokenAddr) public onlyOwner {
        ERC20(_tokenAddr).transfer(msg.sender, ERC20(_tokenAddr).balanceOf(address(this)));
    }
}