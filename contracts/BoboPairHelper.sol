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
    function getOrderNumber(OrderStatus _orderStatus) view external returns(uint256);
    function sealedOrdersMap(OrderStatus _orderStatus, uint256 _index) view external returns(uint256);
    function getCurrentPrice(address _boboRouter) view external returns(uint256);
    function volumnOf24Hours() view external returns(uint256);
}

interface IBoboTradeMining {
    function nftToken() view external returns(address);
    function getUserNFTNumber(address _user) view external returns(uint256);
    function getUserNFTIds(address _user, uint256 _fromIndex, uint256 _toIndex) view external returns(uint256[] memory nftIds);
}

interface IBoboFactory {
    function getPair(address tokenA, address tokenB) view external returns(address);
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
                uint256 weight = nftInfo.weight;
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
            address ownerAddr = orderNFT.ownerOf(nftInfo.id);   // 即便是用户下的订单，也会因为其它操作而失去owner身份，譬如抵押、交易后owner转移
            if (nftInfo.status == OrderStatus.AMMDeal && ownerAddr == _userAddr && nftInfo.dealedTime >= _startTime && nftInfo.dealedTime < _endTime) {
                uint256 weight = nftInfo.weight;
                orderIds[count] = nftInfo.id;
                weights[count] = weight;
                count++;
            }
        }
    }

    function getAllUnhangingOrders(IBoboPair _boboPair, address _userAddr, uint256 _fromIndex, uint256 _pageSize) 
        view public returns(NFTInfo[] memory nftInfos, uint256 count) {
        uint256 orderNumber = _boboPair.getUserOrderNumber(_userAddr);
        if (_fromIndex <= orderNumber - 1) {
            _pageSize = (_fromIndex + _pageSize) > orderNumber ? (orderNumber - _fromIndex) : _pageSize;
            nftInfos = new NFTInfo[](_pageSize);
            IOrderNFT orderNFT = IOrderNFT(_boboPair.orderNFT());
            for (uint256 i = _fromIndex; i < _fromIndex + _pageSize; i++) {
                uint256 orderId = _boboPair.userOrdersMap(_userAddr, i);
                NFTInfo memory nftInfo = orderNFT.getOrderInfo(orderId);
                nftInfos[count] = nftInfo;
                count++;
            } 
        }
    }

    function getOneStatusOrders(IBoboPair _boboPair, OrderStatus _orderStatus, uint256 _fromIndex, uint256 _pageSize) 
        view public returns(NFTInfo[] memory nftInfos, uint256 count) {
        uint256 orderNumber = _boboPair.getOrderNumber(_orderStatus);
        if (_fromIndex <= orderNumber - 1) {
            _pageSize = (_fromIndex + _pageSize) > orderNumber ? (orderNumber - _fromIndex) : _pageSize;
            nftInfos = new NFTInfo[](_pageSize);
            IOrderNFT orderNFT = IOrderNFT(_boboPair.orderNFT());
            for (uint256 i = _fromIndex; i < _fromIndex + _pageSize; i++) {
                uint256 orderId = _boboPair.sealedOrdersMap(_orderStatus, i);
                NFTInfo memory nftInfo = orderNFT.getOrderInfo(orderId);
                nftInfos[count] = nftInfo;
                count++;
            } 
        }
    }

    function getAllDealedOrders(IBoboPair _boboPair, address _userAddr, uint256 _fromIndex, uint256 _pageSize) 
        view public returns(NFTInfo[] memory nftInfos, uint256 count) {
        uint256 orderNumber = _boboPair.getUserDealedOrderNumber(_userAddr);

        if (_fromIndex <= orderNumber - 1) {
            _pageSize = (_fromIndex + _pageSize) > orderNumber ? (orderNumber - _fromIndex) : _pageSize;
            nftInfos = new NFTInfo[](_pageSize);
            IOrderNFT orderNFT = IOrderNFT(_boboPair.orderNFT());
            for (uint256 i = _fromIndex; i < _fromIndex + _pageSize; i++) {
                uint256 orderId = _boboPair.userDealedOrdersMap(_userAddr, i);
                NFTInfo memory nftInfo = orderNFT.getOrderInfo(orderId);
                nftInfos[count] = nftInfo;
                count++;
            } 
        }
    }

    function getAllDepositedOrders(IBoboTradeMining _boboTradeMining, address _usderAddr) view public returns(NFTInfo[] memory nftInfos) {
        uint256 orderLength = _boboTradeMining.getUserNFTNumber(_usderAddr);
        uint256[] memory orderIds = _boboTradeMining.getUserNFTIds(_usderAddr, 0, orderLength);
        nftInfos = new NFTInfo[](orderLength);
        IOrderNFT orderNFT = IOrderNFT(_boboTradeMining.nftToken());
        for (uint256 i = 0; i < orderLength; i++) {
            uint256 orderId = orderIds[i];
            NFTInfo memory nftInfo = orderNFT.getOrderInfo(orderId);
            nftInfos[i] = nftInfo;
        } 
    }

    function getPairInfo(address boboFactory, address boboRouter, address[] memory quoteTokenOfUsdt, address usdtAddr, address[] memory quoteTokenOfUsdc, address usdcAddr) 
        view public returns(uint256[] memory pricesOfUsdt, uint256[] memory volumnsOfUsdt, 
                            uint256[] memory pricesOfUsdc, uint256[] memory volumnsOfUsdc) {
        
        uint256 usdtTokenLength = quoteTokenOfUsdt.length;
        pricesOfUsdt = new uint256[](usdtTokenLength);
        volumnsOfUsdt = new uint256[](usdtTokenLength);

        uint256 usdcTokenLength = quoteTokenOfUsdc.length;
        pricesOfUsdc = new uint256[](usdcTokenLength);
        volumnsOfUsdc = new uint256[](usdcTokenLength);

        for (uint256 i = 0; i < usdtTokenLength; i++) {
            address quoteTokenAddr = quoteTokenOfUsdt[i];
            address pairAddr = IBoboFactory(boboFactory).getPair(quoteTokenAddr, usdtAddr);
            if (pairAddr == address(0)) continue;
            pricesOfUsdt[i] = IBoboPair(pairAddr).getCurrentPrice(boboRouter);
            volumnsOfUsdt[i] = IBoboPair(pairAddr).volumnOf24Hours();
        }

        for (uint256 i = 0; i < usdcTokenLength; i++) {
            address quoteTokenAddr = quoteTokenOfUsdc[i];
            address pairAddr = IBoboFactory(boboFactory).getPair(quoteTokenAddr, usdcAddr);
            if (pairAddr == address(0)) continue;
            pricesOfUsdc[i] = IBoboPair(pairAddr).getCurrentPrice(boboRouter);
            volumnsOfUsdc[i] = IBoboPair(pairAddr).volumnOf24Hours();
        }
    }

    function getPairAddressList(address boboFactory, address[] memory quoteTokenOfUsdt, address usdtAddr, address[] memory quoteTokenOfUsdc, address usdcAddr) 
        view public returns(address[] memory pairAddressListOfUsdt, address[] memory pairAddressListOfUsdc) {
        
        uint256 usdtTokenLength = quoteTokenOfUsdt.length;
        pairAddressListOfUsdt = new address[](usdtTokenLength);

        uint256 usdcTokenLength = quoteTokenOfUsdc.length;
        pairAddressListOfUsdc = new address[](usdcTokenLength);

        for (uint256 i = 0; i < usdtTokenLength; i++) {
            address quoteTokenAddr = quoteTokenOfUsdt[i];
            address pairAddr = IBoboFactory(boboFactory).getPair(quoteTokenAddr, usdtAddr);
            pairAddressListOfUsdt[i] = pairAddr;
        }

        for (uint256 i = 0; i < usdcTokenLength; i++) {
            address quoteTokenAddr = quoteTokenOfUsdc[i];
            address pairAddr = IBoboFactory(boboFactory).getPair(quoteTokenAddr, usdcAddr);
            pairAddressListOfUsdc[i] = pairAddr;
        }
    }
}