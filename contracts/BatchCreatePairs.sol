// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./BoboFactory.sol";
import "./BoboFarmer.sol";
import "./BoboRouter.sol";
import "./BoboPair.sol";
import "./StratMaticSushi.sol";
import "./manager/EXManager.sol";
import "./common/orderNFT.sol";
import "./common/orderDetailNFT.sol";

// 0x1393A1581652E2Bf204A5cA55D64dF9Ea89416f4
contract BatchCreatPairs {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    
    address public constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address public constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    
    
    address[] public USDT_PEERS = [
                  0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
                  0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
                  0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6, 
                  0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, 
                  0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, 
                  0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39, 
                  0x9c2C5fd7b07E95EE044DDeba0E97a665F142394f, 
                  0xb33EaAd8d922B1083446DC23f610c2567fB5180f,
                  0xD6DF932A45C0f255f85145f286eA0b292B21C90B
                ];
    
    address[] public USDC_PEERS = [
                  0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
                  0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
                  0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6, 
                  0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, 
                  0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39, 
                  0x9c2C5fd7b07E95EE044DDeba0E97a665F142394f, 
                  0xb33EaAd8d922B1083446DC23f610c2567fB5180f,
                  0xD6DF932A45C0f255f85145f286eA0b292B21C90B 
                ];
                
    BoboFactoryOnMatic public boboFactory = BoboFactoryOnMatic(0x0326D887A6dde69E874EA70Fd842658125Eafc41);
    BoboFarmer public boboFarmer = BoboFarmer(0xd79Df7Ec6Ff4f5dDc53A3D60ecaf25316a532baD);
    StratMaticSushi public strat;
    address public boboRouter;
    
    
    EXManager public exManager = EXManager(0x7a29BefCb6d0c6FEBdD33003Fa08b139C63C2367);
    OrderNFT public orderNFT = OrderNFT(0x04673384398379a84d05895456AE02fc05B4a509);
    OrderDetailNFT public orderDetailNFT = OrderDetailNFT(0x75508A1de2183a1F2Bf1822d6794698c953A1788);
    
    constructor (address _boboRouter, address _factory, address _farmer, address _exManager, address _orderNFT, address _orderDetailNFT) public {  
        setAddrs(_boboRouter, _factory, _farmer, _exManager, _orderNFT, _orderDetailNFT);
    }
    
    function setAddrs(address _boboRouter, address _factory, address _farmer, address _exManager, address _orderNFT, address _orderDetailNFT) public {
        boboRouter = _boboRouter;
        boboFactory = BoboFactoryOnMatic(_factory);
        boboFarmer = BoboFarmer(_farmer);
        exManager = EXManager(_exManager);
        orderNFT = OrderNFT(_orderNFT);
        orderDetailNFT = OrderDetailNFT(_orderDetailNFT);
    }

    function setFactory(address _factory) public {
        boboFactory = BoboFactoryOnMatic(_factory);
    }
    
    function creatOnePair(address _quoteToken, address _baseToken) public {        
        address pairAddr = boboFactory.createPair(_quoteToken, _baseToken);
        BoboPair(pairAddr).setExManager(address(exManager));
        BoboPair(pairAddr).setRouter(boboRouter);
        orderNFT.addMinter(pairAddr);
        orderDetailNFT.addMinter(pairAddr);
        boboFarmer.addAuthorized(pairAddr);
        EXManager(exManager).addAuth(pairAddr);
    }
    
    function creatUSDTPeers(uint256 _fromIndex, uint256 _toIndex) public {
        for (uint256 i = _fromIndex; i < _toIndex; i++) {
            address usdtPeer = USDT_PEERS[i];
            if (boboFactory.getPair(usdtPeer, USDT) == address(0)) {
                creatOnePair(usdtPeer, USDT);
            }
        }
    }
    
        
    function creatUSDCPeers(uint256 _fromIndex, uint256 _toIndex) public {
        for (uint256 i = _fromIndex; i < _toIndex; i++) {
            address usdcPeer = USDC_PEERS[i];
            if (boboFactory.getPair(usdcPeer, USDC) == address(0)) {
                creatOnePair(usdcPeer, USDC);
            }
        }
    }
    
    function transferAllOwner(address _newOwner) public {
        boboFactory.transferOwnership(_newOwner);
        boboFarmer.transferOwnership(_newOwner);
        exManager.transferOwnership(_newOwner);
        orderNFT.transferOwnership(_newOwner);
        orderDetailNFT.transferOwnership(_newOwner);
    }
}