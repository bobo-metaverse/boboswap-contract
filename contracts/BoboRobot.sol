// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;


interface IBoboPair {
    function getCurrentPrice() external view returns(uint256);
}


contract BoboRobot {
    
    // function executeInnerOrder(uint256 _orderId) private returns(uint256 amountOut) {
    //     NFTInfo memory orderInfo = orderNFT.getOrderInfo(_orderId); 
    //     (address inToken, address outToken) = orderInfo.bBuyQuoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);
        
    //     uint256 deductAmount = exManager.deductTradeFee(orderInfo.owner, inToken, orderInfo.inAmount);
    //     if (deductAmount > 0) {
    //         ERC20(inToken).transferFrom(msg.sender, address(exManager), deductAmount);
    //     }
    //     uint256 amountIn = orderInfo.inAmount.sub(deductAmount);

    //     (, ResultInfo memory bestSwapInfo) = boboRouter.getBestSwapPath(inToken, outToken, amountIn);
    //     if (bestSwapInfo.totalAmountOut >= orderInfo.minOutAmount) {
    //         if (boboFarmer.tokenPidMap(inToken) > 0) {
    //             boboFarmer.withdraw(inToken, orderInfo.owner, amountIn);
    //         }
    //         amountOut = swap(_orderId, bestSwapInfo, inToken, outToken, amountIn, true);
    //     } else {
    //         setExceptionOrder(_orderId, "Amount out can NOT satisfy the min amount out of order.");
    //     }
    // }
    
    // // 执行一笔买单或卖单（满足价格条件）
    // function executeHeaderOrder(address _pairAddr) public returns(bool) {
    //     uint256 currentPrice = IBoboPair(_pairAddr).getCurrentPrice();
        
    //     (bool existOfBuy, uint256 orderIdOfBuy) = getHeaderOrderIndex(true);
    //     uint256 highestPriceOfBuy = existOfBuy ? getValue(orderIdOfBuy) : 0;
        
    //     (bool existOfSell, uint256 orderIdOfSell) = getHeaderOrderIndex(false);
    //     uint256 lowestPriceOfSell = existOfSell ? getValue(orderIdOfSell) : uint256(-1);
        
    //     uint256 executedOrderId = 0;
    //     if (currentPrice <= highestPriceOfBuy) {
    //         executedOrderId = orderIdOfBuy;
    //     } else if (currentPrice > lowestPriceOfSell) {
    //         executedOrderId = orderIdOfSell;
    //     }
    //     if (executedOrderId > 0) {  
    //         executeInnerOrder(executedOrderId);
    //         return true;
    //     }
    //     return false;
    // }

    // // 根据配置连续检查并执行多笔订单
    // // 当当前价格不满足要求时，便退出
    // function checkOrderList() public {
    //     uint256 maxOrderNumberPerMatch = exManager.maxOrderNumberPerMatch();
    //     while(maxOrderNumberPerMatch-- > 0) {
    //         bool result = executeHeaderOrder();
    //         if (!result) break;
    //     }
    // }
}