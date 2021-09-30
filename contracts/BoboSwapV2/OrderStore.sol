// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./BasicStruct.sol";

contract OrderStore is IStructureInterface, IERC721Receiver {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using StructuredLinkedList for StructuredLinkedList.List;

    IOrderNFT public orderNFT;
    mapping(address => uint256[]) public userDealedOrdersMap;  // 用户所有成功成交的订单
    mapping(address => uint256[]) public userOrdersMap;  // 用户所有订单
    mapping(address => EnumerableSet.UintSet) private userHangingOrdersMap;  // 用户所有挂单
    mapping(bool => StructuredLinkedList.List) private bBuyOrdersMap;  // 交易对正挂着的订单, bool: true-买单，false-卖单
    mapping(OrderStatus => uint256[]) public sealedOrdersMap;  // 交易对已成交、取消以及异常的订单列表
    
    constructor () public {
    }

    // 根据订单ID获得下单价格
    function getValue(uint256 _nftId) view public override returns(uint256) {
        if (_nftId == 0) return 0;
        OrderInfo memory nftInfo = orderNFT.getOrderInfo(_nftId);
        return nftInfo.spotPrice;
    }
    
    // 增加订单，并将订单插入挂单列表中，参数包括：
    // 交易对地址、下单用户、是否买入token0，下单价格，下单数量、最小成交量、订单类型（仅交易，交易后提矿，交易后提矿并将矿转成U），订单状态
    function addOrder(uint256 _parentId, bool _bBuyQuoteToken, uint256 _spotPrice, uint256 _inAmount, uint256 _minOutAmount) internal returns(uint256) {
        uint256 orderId = orderNFT.mint(_parentId, address(this), msg.sender, _bBuyQuoteToken, _spotPrice, _inAmount, _minOutAmount);
        
        userOrdersMap[msg.sender].push(orderId);
        addHangingOrder(orderId, _bBuyQuoteToken, _spotPrice);

        userHangingOrdersMap[msg.sender].add(orderId);
        return orderId;
    }
    
    // 将订单插入有序的挂单列表中，按照下单价格排序
    // 1: 买单，队列按照从大到小排列，先进先出
    // 2: 卖单，队列按照从小到大排列，先进先出
    function addHangingOrder(uint256 _orderId, bool _bBuyQuoteToken, uint256 _spotPrice) private returns(bool) {
        uint256 next = bBuyOrdersMap[_bBuyQuoteToken].getSortedSpot(address(this), _spotPrice, _bBuyQuoteToken);
        
        return bBuyOrdersMap[_bBuyQuoteToken].insertBefore(next, _orderId);
    }
    
    function removeOrder(OrderInfo memory _orderInfo) private returns(bool) {
        orderNFT.transferFrom(address(this), _orderInfo.owner, _orderInfo.id);
        sealedOrdersMap[_orderInfo.status].push(_orderInfo.id);
        userHangingOrdersMap[msg.sender].remove(_orderInfo.id);
        uint256 node = bBuyOrdersMap[_orderInfo.bBuyQuoteToken].remove(_orderInfo.id);
        return node > 0;
    }
    
    // 被用户手动取消订单
    function setManualCancelOrder(uint256 _orderId) internal returns(bool) {
        OrderInfo memory orderInfo = orderNFT.getOrderInfo(_orderId);
        
        require(orderInfo.owner == msg.sender, "OrderStore: only book owner can cancel the order.");
        require(orderInfo.status == OrderStatus.Hanging, "OrderStore: only hanging order can be canceled.");
        
        orderNFT.sealNFT(_orderId, OrderStatus.ManualCanceled, 0);
        sealedOrdersMap[OrderStatus.ManualCanceled].push(_orderId);
        removeOrder(orderInfo);
    }
    
    function setDealedOrder(uint256 _orderId, uint256 _outAmount) internal returns(bool) {
        OrderInfo memory orderInfo = orderNFT.getOrderInfo(_orderId);
        
        require(orderInfo.status == OrderStatus.Hanging, "OrderStore: only hanging order can become Dealed status.");
        
        orderNFT.sealNFT(_orderId, OrderStatus.Dealed, _outAmount);
        sealedOrdersMap[OrderStatus.Dealed].push(_orderId);
        userDealedOrdersMap[orderInfo.owner].push(_orderId);
        removeOrder(orderInfo);
    }

    // 获取盘口第一笔卖单或买单数据
    function getHeaderOrderIndex(bool _bBuy) view public returns(bool exist, uint256 index) {
        return bBuyOrdersMap[_bBuy].getAdjacent(0, true);   // get the first node of the list
    }
    
    function getTotalOrderNumber(bool _bBuy) view public returns(uint256) {
        return bBuyOrdersMap[_bBuy].sizeOf();
    }
    // 按序获取交易对的挂单信息
    function getOrderInfos(bool _bBuy, uint256 _fromIndex, uint256 _toIndex) view public returns(OrderInfo[] memory orderInfos) {
        uint256 length = bBuyOrdersMap[_bBuy].sizeOf();
        if (_toIndex > length) _toIndex = length;
        require(_fromIndex < _toIndex, "OrderStore: index is out of bound.");
        
        orderInfos = new OrderInfo[](_toIndex - _fromIndex);
        uint256 index = 0;
        (bool exist, uint256 currentId) = bBuyOrdersMap[_bBuy].getNextNode(0);
        while(index < _toIndex && exist) {
            if (index < _fromIndex) {
                (exist, currentId) = bBuyOrdersMap[_bBuy].getNextNode(currentId);
                index++;
                continue;
            }
            OrderInfo memory orderInfo = orderNFT.getOrderInfo(currentId);
            orderInfos[index - _fromIndex] = orderInfo;
            
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

    // 获取用户所有已成交的订单数量
    function getUserDealedOrderNumber(address _userAddr) view public returns(uint256) {
        return userDealedOrdersMap[_userAddr].length;
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

    function getUserHangingOrderInfos(address _userAddr, uint256 _fromIndex, uint256 _toIndex) view public returns(OrderInfo[] memory orderInfos) {
        uint256 length = userHangingOrdersMap[_userAddr].length();
        if (_toIndex > length) _toIndex = length;
        require(_fromIndex < _toIndex, "OrderStore: index is out of bound.");
        
        orderInfos = new OrderInfo[](_toIndex - _fromIndex);
        for (uint256 i = _fromIndex; i < _toIndex; i++) {
            uint256 orderId = userHangingOrdersMap[_userAddr].at(i);
            OrderInfo memory orderInfo = orderNFT.getOrderInfo(orderId);
            orderInfos[i - _fromIndex] = orderInfo;
        }
    }

    function getOrderNumber(OrderStatus _orderStatus) view public returns(uint256) {
        return sealedOrdersMap[_orderStatus].length;
    }
    
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}