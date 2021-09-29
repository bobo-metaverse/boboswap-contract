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
    function getOrderInfos(bool _bBuy, uint256 _fromIndex, uint256 _toIndex) view external returns(NFTInfo[] memory orderInfos);
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

    // 1: 用户下市价单时，从pair调用到此接口，此接口先处理挂单，如还有剩余token未成交，再调用BoboRouter接口，让其同AMM进行交易
    // 
    function swap(address _inToken, address _outToken, uint256 _amountIn, uint256 _minAmountOut, address _orderOwner) public {
        IERC20(_inToken).transferFrom(msg.sender, address(this), _amountIn);

        address boboPairAddr = boboFactory.getPair(_inToken, _outToken);
        IBoboPair boboPair = IBoboPair(boboPairAddr);
        address baseToken = boboPair.baseToken();
        bool bBuyQuoteToken = baseToken == _inToken;   // true: 表示要swap的订单是买单，需要找卖单匹配  false: 表示swap的订单是卖单，需要找卖单匹配
        uint256 quoteTokenDecimals = bBuyQuoteToken ? ERC20(_outToken).decimals() : ERC20(_inToken).decimals();
        uint256 spotPrice = bBuyQuoteToken ? _amountIn.mul(10**quoteTokenDecimals).div(_minOutAmount) 
                                           : _minOutAmount.mul(10**quoteTokenDecimals).div(_amountIn);

        uint256 orderNumber = boboPair.getTotalOrderNumber(!bBuyQuoteToken);
        uint256 step = 1;
        for (uint256 fromIndex = 0; fromIndex < orderNumber; fromIndex += step) {
            uint256 toIndex = fromIndex + step;
            if (toIndex > orderNumber)
                toIndex = orderNumber;

            NFTInfo[] memory orderInfos = getOrderInfos(!bBuyQuoteToken, fromIndex, toIndex);
            NFTInfo memory orderInfo = orderInfos[0];
            if (bBuyQuoteToken && spotPrice >= orderInfo.spotPrice) {  // 对于买单，需要匹配价格不比它高的卖单
                if (_amountIn >= orderInfo.minAmountOut) {  // 输入的inToken数量满足卖单所需，可以完全吃掉此订单

                } else {  // 无法完全吃掉此订单，只能吃一部分

                }
            } else if (!bBuyQuoteToken && spotPrice <= orderInfo.spotPrice) {  // 对于卖单，需要匹配价格不比它低的买单

            }
            
            boboPair.executeSpecifiedOrder(address(this), orderInfo.id, amountIn);
        }
    }
}