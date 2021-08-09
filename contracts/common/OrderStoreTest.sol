// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./BasicStruct.sol";

contract OrderStore is IStructureInterface, IERC721Receiver {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using StructuredLinkedList for StructuredLinkedList.List;

    IOrderNFT public orderNFT;
    IOrderDetailNFT public orderDetailNFT;
    mapping(address => uint256[]) public userOrdersMap;  // 用户所有订单
    mapping(address => EnumerableSet.UintSet) private userHangingOrdersMap;  // 用户所有挂单
    mapping(bool => StructuredLinkedList.List) private bBuyOrdersMap;  // 交易对正挂着的订单, bool: true-买单，false-卖单
    mapping(OrderStatus => uint256[]) public sealedOrdersMap;  // 交易对已成交、取消以及异常的订单列表
    
    constructor (address _orderNFT, address _orderDetailNFT) public {
        orderNFT = (IOrderNFT)(_orderNFT);
        orderDetailNFT = (IOrderDetailNFT)(_orderDetailNFT);
    }
    
    // 根据订单ID获得下单价格
    function getValue(uint256 _nftId) view public override returns(uint256) {
        if (_nftId == 0) return 0;
        NFTInfo memory nftInfo = orderNFT.getOrderInfo(_nftId);
        return nftInfo.spotPrice;
    }

    // 增加订单，并将订单插入挂单列表中，参数包括：
    // 交易对地址、下单用户、是否买入token0，下单价格，下单数量、最小成交量、订单类型（仅交易，交易后提矿，交易后提矿并将矿转成U），订单状态
    function addOrder(bool _bBuyQuoteToken, uint256 _spotPrice, uint256 _inAmount, uint256 _minOutAmount) public returns(uint256) {
        uint256 orderId = orderNFT.mint(address(this), msg.sender, _bBuyQuoteToken, _spotPrice, _inAmount, _minOutAmount);
        
        userOrdersMap[msg.sender].push(orderId);
        addHangingOrder(orderId, _bBuyQuoteToken, _spotPrice);

        userHangingOrdersMap[msg.sender].add(orderId);
        return orderId;
    }
    
    function addOrderDetail(address _orderOwner, uint256 _orderId, uint256 _inAmount, uint256 _outAmount, SwapPool _swapPool, address[] memory _path) public returns(uint256) {
        uint256 orderDetailId = orderDetailNFT.mint(_orderOwner, _inAmount, _outAmount, _orderId, _swapPool, _path);
        return orderDetailId;
    }

    // 将订单插入有序的挂单列表中，按照下单价格排序
    // 1: 买单，队列按照从大到小排列，相同值，后进的排在后面
    // 2: 卖单，队列按照从小到大排列，相同值，后进的排后面
    function addHangingOrder(uint256 _orderId, bool _bBuyQuoteToken, uint256 _spotPrice) private returns(bool) {
        uint256 next = bBuyOrdersMap[_bBuyQuoteToken].getSortedSpot(address(this), _spotPrice, _bBuyQuoteToken);
        
        return bBuyOrdersMap[_bBuyQuoteToken].insertBefore(next, _orderId);
    }
    
    function removeOrder(NFTInfo memory _orderInfo) private returns(bool) {
        orderNFT.transferFrom(address(this), _orderInfo.owner, _orderInfo.id);
        sealedOrdersMap[_orderInfo.status].push(_orderInfo.id);
        userHangingOrdersMap[msg.sender].remove(_orderInfo.id);
        uint256 node = bBuyOrdersMap[_orderInfo.bBuyQuoteToken].remove(_orderInfo.id);
        return node > 0;
    }
    
    // 被用户手动取消订单
    function setManualCancelOrder(uint256 _orderId) internal returns(bool) {
        NFTInfo memory orderInfo = orderNFT.getOrderInfo(_orderId);
        
        require(orderInfo.owner == msg.sender, "OrderStore: only book owner can cancel the order.");
        require(orderInfo.status == OrderStatus.Hanging, "OrderStore: only hanging order can be canceled.");
        
        orderNFT.sealNFT(_orderId, OrderStatus.ManualCanceled, 0, "");
        sealedOrdersMap[OrderStatus.ManualCanceled].push(_orderId);
        removeOrder(orderInfo);
    }
    
    function setAMMDealOrder(uint256 _orderId, uint256 _outAmount) internal returns(bool) {
        NFTInfo memory orderInfo = orderNFT.getOrderInfo(_orderId);
        
        require(orderInfo.status == OrderStatus.Hanging, "OrderStore: only hanging order can become AMMDeal status.");
        
        orderNFT.sealNFT(_orderId, OrderStatus.AMMDeal, _outAmount, "");
        sealedOrdersMap[OrderStatus.AMMDeal].push(_orderId);
        removeOrder(orderInfo);
    }
    
    function setExceptionOrder(uint256 _orderId, string memory _comment) internal returns(bool) {
        NFTInfo memory orderInfo = orderNFT.getOrderInfo(_orderId);
        
        require(orderInfo.status == OrderStatus.Hanging, "OrderStore: only hanging order can become exception status.");
        
        orderNFT.sealNFT(_orderId, OrderStatus.Exception, 0, _comment);
        sealedOrdersMap[OrderStatus.Exception].push(_orderId);
        removeOrder(orderInfo);
    }

    function getRestInOutAmount(uint256 _orderId) view internal returns(uint256, uint256) {
        NFTInfo memory orderInfo = orderNFT.getOrderInfo(_orderId);
        
        uint256 inAmount = orderInfo.inAmount;   // 用户下单时，给到合约的那个token的数量
        uint256 minOutAmount = orderInfo.minOutAmount;  // 用户下单时，期望获得的最小的兑换出来的token的数量
        uint256[] memory orderDetailIds = orderNFT.orderDetailIds(_orderId);
        for (uint256 i = 0; i < orderDetailIds.length; i++) {
            NFTDetailInfo memory detailInfo = orderDetailNFT.getOrderDetailInfo(orderDetailIds[i]);
            inAmount = inAmount.sub(detailInfo.outAmount);              // detailInfo.outAmount是指订单每成交一次时被兑换出去的token数量
            minOutAmount = minOutAmount.sub(detailInfo.inAmount);       // detailInfo.inAmount是指订单每成交一次时收到的token数量
        }
        return (inAmount, minOutAmount);
    }

    // 获取盘口第一笔卖单或买单数据
    function getHeaderOrderIndex(bool _bBuy) view public returns(bool exist, uint256 index) {
        return bBuyOrdersMap[_bBuy].getAdjacent(0, true);   // get the first node of the list
    }
    
    function getTotalOrderNumber(bool _bBuy) view public returns(uint256) {
        return bBuyOrdersMap[_bBuy].sizeOf();
    }
    
    function getOrderInfos(bool _bBuy, uint256 _fromIndex, uint256 _toIndex) view public returns(uint256[] memory orderIds, uint256[] memory orderPrices) {
        uint256 length = bBuyOrdersMap[_bBuy].sizeOf();
        if (_toIndex > length) _toIndex = length;
        require(_fromIndex < _toIndex, "OrderStore: index is out of bound.");
        
        orderIds = new uint256[](_toIndex - _fromIndex);
        orderPrices = new uint256[](_toIndex - _fromIndex);
        uint256 index = 0;
        (bool exist, uint256 currentId) = bBuyOrdersMap[_bBuy].getNextNode(0);
        while(index < _toIndex && exist) {
            if (index < _fromIndex) {
                (exist, currentId) = bBuyOrdersMap[_bBuy].getNextNode(currentId);
                index++;
                continue;
            }
            orderIds[index - _fromIndex] = currentId;
            NFTInfo memory orderInfo = orderNFT.getOrderInfo(currentId);
            orderPrices[index - _fromIndex] = orderInfo.spotPrice;
            
            (exist, currentId) = bBuyOrdersMap[_bBuy].getNextNode(currentId);
            index++;
        }
    }


    // 弹出盘口第一笔卖单或买单数据
    function popFront(bool _bBuy) internal returns(uint256 index) {
        return bBuyOrdersMap[_bBuy].popFront();
    }
    // 将订单号插入盘口
    function pushFront(bool _bBuy, uint256 _index) internal returns(bool) {
        return bBuyOrdersMap[_bBuy].pushFront(_index);
    }
    // 获取订单细节数量
    function getOrderDetailNumber(uint256 _orderId) view public returns(uint256) {
        return orderNFT.getOrderDetailNumber(_orderId);
    }
    // 获取用户所有订单数量
    function getUserOrderNumber(address _userAddr) view public returns(uint256) {
        return userOrdersMap[_userAddr].length;
    }
    // 获取用户所有挂单数量
    function getUserHangingOrderNumber(address _userAddr) view public returns(uint256) {
        return userHangingOrdersMap[_userAddr].length();
    }
    // 获取用户挂单
    function getUserHangingOrderId(address _userAddr, uint256 _index) view public returns(uint256) {
        return userHangingOrdersMap[_userAddr].at(_index);
    }
    // 获取某个交易对一段时间内基础token的交易量
    function getTotalDealedAmount(uint256 _fromTime, uint256 _endTime) view public returns(uint256 fromIndex, uint256 totalAmount) {
        uint256 orderLength = sealedOrdersMap[OrderStatus.AMMDeal].length;
        
        uint256 lowIndex = 0;
        uint256 highIndex = 0;
        while(lowIndex <= highIndex) {
            uint256 midIndex = lowIndex.add(highIndex).div(2);
            if (midIndex == 0) {
                fromIndex = 0;
                break;
            }
            uint256 orderId = sealedOrdersMap[OrderStatus.AMMDeal][midIndex];
            uint256 preOrderId = sealedOrdersMap[OrderStatus.AMMDeal][midIndex - 1];
            NFTInfo memory orderInfo = orderNFT.getOrderInfo(orderId);
            NFTInfo memory preOrderInfo = orderNFT.getOrderInfo(preOrderId);
            if (orderInfo.dealedTime == _fromTime || preOrderInfo.dealedTime == _fromTime) {
                fromIndex = orderInfo.dealedTime == _fromTime ? midIndex : midIndex - 1;
                break;
            } else if (preOrderInfo.dealedTime < _fromTime && orderInfo.dealedTime > _fromTime) {
                fromIndex = midIndex;
                break;
            } else if (orderInfo.dealedTime > _fromTime) {
                highIndex = midIndex;
            } else {
                lowIndex = midIndex;
            }
        }
        
        uint256 index = fromIndex;
        while (index < orderLength) {
            uint256 orderId = sealedOrdersMap[OrderStatus.AMMDeal][index];
            NFTInfo memory orderInfo = orderNFT.getOrderInfo(orderId);
            
            if (orderInfo.dealedTime > _endTime) break;
            
            totalAmount = totalAmount.add(orderInfo.bBuyQuoteToken ? orderInfo.inAmount : orderInfo.outAmount);
        }
    }
    
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}