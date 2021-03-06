// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../BoboFactory.sol";
import "../BoboFarmer4HangingOrder.sol";
import "../BoboPair.sol";
import "../StratMaticSushi.sol";
import "../common/orderNFT.sol";
import "../common/BasicStruct.sol";

contract BoboSwapTester {
    // using SafeMath for uint256;
    // address public constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    // address public constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    // address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    // BoboFactory public boboFactory;
    // BoboFarmer public boboFarmer;
    // StratMaticSushi public stratMaticSushi;
    // OrderNFT public orderNFT;

    // constructor (address _boboFactory, address _boboFarmer, address _stratMaticSushi, address _orderNFT) public {  
    //     setAddrs(_boboFactory, _boboFarmer, _stratMaticSushi, _orderNFT);
    // }

    // function setAddrs(address _boboFactory, address _boboFarmer, address _stratMaticSushi, address _orderNFT) public {
    //     boboFactory = BoboFactory(_boboFactory);
    //     boboFarmer = BoboFarmer(_boboFarmer);
    //     stratMaticSushi = StratMaticSushi(_stratMaticSushi);
    //     orderNFT = OrderNFT(_orderNFT);
    // }

    // function approveToken() public {
    //     address pairAddr = boboFactory.getPair(USDT, WMATIC);
    //     ERC20(USDT).approve(pairAddr, uint256(-1));
    //     ERC20(WMATIC).approve(pairAddr, uint256(-1));

    //     pairAddr = boboFactory.getPair(USDC, WMATIC);
    //     ERC20(USDC).approve(pairAddr, uint256(-1));
    //     ERC20(WMATIC).approve(pairAddr, uint256(-1));
    // }

    // function addLimitedOrder(address _boboRouter, bool _bBuy, bool bUsdt, uint256 _spotPrice, uint256 _amountIn, uint256 _slippagePercent) public {
    //     address baseToken = bUsdt ? USDT : USDC;
    //     address pairAddr = boboFactory.getPair(baseToken, WMATIC);        
    //     BoboPair boboPair = BoboPair(pairAddr);
    //     (uint256 preBaseTokenAmount, uint256 preQuoteTokenAmount) = boboPair.getTotalHangingTokenAmount(address(this));
    //     uint256 preOrderNumber = boboPair.getTotalOrderNumber(_bBuy);

    //     address inToken = _bBuy ? baseToken : WMATIC;
    //     uint256 prePendingBobo = boboFarmer.pendingBOBO(inToken, address(this));
    //     uint256 preWantTokenAmount = boboFarmer.stakedWantTokens(inToken, address(this));

    //     //boboPair.addLimitedOrder(_boboRouter, _bBuy, _spotPrice, _amountIn, _slippagePercent);
    //     checkBoboPair(boboPair, _bBuy, _amountIn, preOrderNumber, preBaseTokenAmount, preQuoteTokenAmount);
    //     checkBoboFarmer(_bBuy, _amountIn, inToken, prePendingBobo, preWantTokenAmount);
    // }
    
    // function checkBoboPair(BoboPair boboPair, bool _bBuy, uint256 _amountIn, uint256 preOrderNumber, uint256 preBaseTokenAmount, uint256 preQuoteTokenAmount) view private {
    //     (uint256 baseTokenAmount, uint256 quoteTokenAmount) = boboPair.getTotalHangingTokenAmount(address(this));
    //     uint256 orderNumber = boboPair.getTotalOrderNumber(_bBuy);

    //     if (_bBuy) {
    //         require(preBaseTokenAmount.add(_amountIn) == baseTokenAmount, "BaseTokenAmount error");
    //     } else {
    //         require(preQuoteTokenAmount.add(_amountIn) == quoteTokenAmount, "BaseTokenAmount error");
    //     }
    //     require(orderNumber.sub(preOrderNumber) == 1, "OrderNumber error");
    // }
    
    // function checkBoboFarmer(bool _bBuy, uint256 _amountIn, address inToken, uint256 prePendingBobo, uint256 preWantTokenAmount) view private {
    //     uint256 pendingBobo = boboFarmer.pendingBOBO(inToken, address(this));   // ??????????????????bobo
    //     uint256 wantTokenAmount = boboFarmer.stakedWantTokens(inToken, address(this));  //
    //     if (_bBuy) {
    //         require(pendingBobo == 0, "Pending Bobo is not zero.");
    //         if (_amountIn > 1100000)
    //             require(wantTokenAmount.sub(preWantTokenAmount).sub(_amountIn) >= 0, "Want token amount error.");
    //     } else {
    //         require(pendingBobo == prePendingBobo, "Pending Bobo is not equal pre bobo.");
    //         require(wantTokenAmount == preWantTokenAmount, "Want token is not equal pre want token.");
    //     }
    // }
    
    // function pendingBobo() view public returns(uint256 usdtBobo, uint256 usdcBobo) {
    //     usdtBobo = boboFarmer.pendingBOBO(USDT, address(this));
    //     usdcBobo = boboFarmer.pendingBOBO(USDC, address(this));
    // }

    // function stakedWantTokens() view public returns(uint256 usdt, uint256 usdc) {
    //     usdt = boboFarmer.stakedWantTokens(USDT, address(this));
    //     usdc = boboFarmer.stakedWantTokens(USDC, address(this));
    // }

    // function getAllOrders(bool bUsdt) view public returns(NFTInfo[] memory orders) {
    //     address baseToken = bUsdt ? USDT : USDC;
    //     address pairAddr = boboFactory.getPair(baseToken, WMATIC);        
    //     BoboPair boboPair = BoboPair(pairAddr);

    //     uint256 number = boboPair.getUserHangingOrderNumber(address(this));
    //     orders = boboPair.getUserHangingOrderInfos(address(this), 0, number);
    // }

    // function cancelOrder(uint256 _orderId) public {
    //     address pairAddr = boboFactory.getPair(USDT, WMATIC);
    //     BoboPair boboPair = BoboPair(pairAddr);
    //     boboPair.cancelOrder(_orderId);

    //     NFTInfo memory orderInfo = orderNFT.getOrderInfo(_orderId); 
    //     require(orderInfo.status == OrderStatus.ManualCanceled, "Order status error");
    //     if (orderInfo.bBuyQuoteToken) {

    //     }
    // }

    // function withdraw(address _token) public {
    //     ERC20(_token).transfer(msg.sender, ERC20(_token).balanceOf(address(this)));
    // }

    // function earn() public {
    //     stratMaticSushi.earn();
    // }
}
