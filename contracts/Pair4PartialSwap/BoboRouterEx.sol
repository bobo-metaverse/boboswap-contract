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

contract BoboRouter is Ownable {
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

    function swap(address _inToken, address _outToken, uint256 _amountIn, uint256 _minAmountOut, address _orderOwner) public {
        address boboPairAddr = boboFactory.getPair(_inToken, _outToken);
        IBoboPair boboPair = IBoboPair(boboPairAddr);
        address baseToken = boboPair.baseToken();
        bool bBuyQuoteToken = baseToken == _inToken;
        uint256 orderNumber = boboPair.getTotalOrderNumber(!bBuyQuoteToken);
        if (orderNumber > 0) {
            
        }
    }
}