// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./common/BasicStruct.sol";

interface IBoboPair {
    function getUserDealedOrderNumber(address _userAddr) view external returns(uint256);
    function userDealedOrdersMap(address _userAddr, uint256 _index) view external returns(uint256);
    function userOrdersMap(address _userAddr, uint256 _index) view external returns(uint256);
    function orderNFT() view external returns(address);
    function getUserOrderNumber(address _userAddr) view external returns(uint256);
}


contract BoboPairHelper {
    function getDepositableOrders(IBoboPair _boboPair, address _userAddr, uint256 _startTime, uint256 _endTime) 
        view public returns(uint256[] memory orderIds, uint256[] memory weights, uint256 count) {
        
        IOrderNFT orderNFT = IOrderNFT(_boboPair.orderNFT());
        uint256 orderNumber = _boboPair.getUserDealedOrderNumber(_userAddr);
        orderIds = new uint256[](orderNumber > 100 ? 100 : orderNumber);
        weights = new uint256[](orderNumber > 100 ? 100 : orderNumber);
        for (uint256 i; i < orderNumber; i++) {
            uint256 orderId = _boboPair.userDealedOrdersMap(_userAddr, i);
            NFTInfo memory nftInfo = orderNFT.getOrderInfo(orderId);
            address ownerAddr = orderNFT.ownerOf(nftInfo.id);
            if (ownerAddr == _userAddr && nftInfo.dealedTime >= _startTime && nftInfo.dealedTime < _endTime) {
                uint256 weight = orderNFT.getWeight(nftInfo.id);
                orderIds[count] = nftInfo.id;
                weights[count] = weight;
                count++;
            }
        }
    }

    function getDepositableOrders_old(IBoboPair _boboPair, address _userAddr, uint256 _startTime, uint256 _endTime) 
        view public returns(uint256[] memory orderIds, uint256[] memory weights, uint256 count) {
        
        IOrderNFT orderNFT = IOrderNFT(_boboPair.orderNFT());
        uint256 orderNumber = _boboPair.getUserOrderNumber(_userAddr);
        orderIds = new uint256[](orderNumber > 100 ? 100 : orderNumber);
        weights = new uint256[](orderNumber > 100 ? 100 : orderNumber);
        for (uint256 i; i < orderNumber; i++) {
            uint256 orderId = _boboPair.userOrdersMap(_userAddr, i);
            NFTInfo memory nftInfo = orderNFT.getOrderInfo(orderId);
            address ownerAddr = orderNFT.ownerOf(nftInfo.id);
            if (nftInfo.status == OrderStatus.AMMDeal && ownerAddr == _userAddr && nftInfo.dealedTime >= _startTime && nftInfo.dealedTime < _endTime) {
                uint256 weight = orderNFT.getWeight(nftInfo.id);
                orderIds[count] = nftInfo.id;
                weights[count] = weight;
                count++;
            }
        }
    }

    function getUnhangingOrders(IBoboPair _boboPair, address _userAddr, bool _onlyDealed, uint256 _fromIndex, uint256 _pageSize) 
        view public returns(NFTInfo[] memory nftInfos, uint256 count) {
        uint256 orderNumber = _boboPair.getUserOrderNumber(_userAddr);
        _pageSize = orderNumber < _pageSize ? orderNumber : _pageSize;

        require(_fromIndex < orderNumber - 1 && _toIndex > _fromIndex, "BoboPairHelper: index input is ERROR.");

        nftInfos = new NFTInfo[](_toIndex - _fromIndex > orderNumber ? orderNumber : _toIndex - _fromIndex);
        for (uint256 i; i < orderNumber; i++) {
            uint256 orderId = _boboPair.userOrdersMap(_userAddr, i);
            NFTInfo memory nftInfo = orderNFT.getOrderInfo(orderId);
            address ownerAddr = orderNFT.ownerOf(nftInfo.id);
            if (nftInfo.status == OrderStatus.AMMDeal && ownerAddr == _userAddr && nftInfo.dealedTime >= _startTime && nftInfo.dealedTime < _endTime) {
                uint256 weight = orderNFT.getWeight(nftInfo.id);
                orderIds[count] = nftInfo.id;
                weights[count] = weight;
                count++;
            }
        }
    }
}