// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./common/OrderStore.sol";
import "./BoboPair.sol";

interface IMinter {
    function addMinter(address _addMinter) external returns (bool);
}

interface IAuthorizable {
    function addAuthorized(address _authorizedAddr) external returns (bool);
}

interface IBoboPair is IAuthorizable {
    function initialize(address _token0, address _token1, address _authAddr, address _boboFarmer, address _orderNFT, address _orderDetailNFT) external;
    function setRouter(address _router) external;
    function setExManager(address _exManager) external;
    function getTotalHangingTokenAmount(address _userAddr) view external returns(uint256 baseTokenAmount, uint256 quoteTokenAmount);
}

contract BoboFactoryOnMatic is Ownable {
    using SafeMath for uint256;
    
    address public constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address public constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    
    address[] public allPairs;  // 交易对列表
    mapping(address => mapping(address => address)) public getPair;
    mapping(address => address[]) public baseTokenPairs;

    IBoboFarmer public boboFarmer;
    address public orderNFT;
    address public orderDetailNFT;
    address public exManager;
    address public boboRouter;
    
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    
    constructor (address _orderNFT, address _orderDetailNFT, address _boboFarmer, address _exManager, address _boboRouter) public {  
        orderNFT = _orderNFT;
        orderDetailNFT = _orderDetailNFT;
        boboFarmer = IBoboFarmer(_boboFarmer);
        exManager = _exManager;
        boboRouter = _boboRouter;
    }

    function setAddresses(address _boboFarmer, address _exManager, address _boboRouter) public onlyOwner {
        if (_boboFarmer != address(0))
            boboFarmer = IBoboFarmer(_boboFarmer);
        if (_exManager != address(0))
            exManager = _exManager;
        if (_boboRouter != address(0))
            boboRouter = _boboRouter;
    }
    
    function createPair(address _quoteToken, address _baseToken) public onlyOwner returns (address pairAddr) {
        require(_quoteToken != _baseToken, "BoboFactory: IDENTICAL_ADDRESSES");
        require(_quoteToken != address(0), "BoboFactory: ZERO_ADDRESS");
        require(getPair[_quoteToken][_baseToken] == address(0), "BoboFactory: PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = type(BoboPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_quoteToken, _baseToken));
        assembly {
            pairAddr := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IBoboPair(pairAddr).initialize(_quoteToken, _baseToken, msg.sender, address(boboFarmer), orderNFT, orderDetailNFT);
        
        setBoboPairInfo(pairAddr);
        
        getPair[_quoteToken][_baseToken] = pairAddr;
        getPair[_baseToken][_quoteToken] = pairAddr; // populate mapping in the reverse direction
        allPairs.push(pairAddr);
        baseTokenPairs[_baseToken].push(_quoteToken);
        emit PairCreated(_quoteToken, _baseToken, pairAddr, allPairs.length);
    }

    function setBoboPairInfo(address _pairAddr) private {
        IBoboPair(_pairAddr).setExManager(exManager);
        IBoboPair(_pairAddr).setRouter(boboRouter);
        
        IMinter(orderNFT).addMinter(_pairAddr);
        IMinter(orderDetailNFT).addMinter(_pairAddr);
        IAuthorizable(address(boboFarmer)).addAuthorized(_pairAddr);
        IAuthorizable(exManager).addAuthorized(_pairAddr);
    }
    
    function pairNumber() view public returns(uint256) {
        return allPairs.length;
    }
    
    function addPairAuth(address _quoteToken, address _baseToken, address _auth) external onlyOwner {
        address pairAddr = getPair[_quoteToken][_baseToken];
        require(pairAddr != address(0), 'BoboFactory: PAIR_NOT_EXISTS');
        IBoboPair(pairAddr).addAuthorized(_auth);
    }

    function getBaseTokenPairLength(address _baseToken) view external returns(uint256) {
        return baseTokenPairs[_baseToken].length;
    }

    function getTotalHangingTokenAmount(address _baseToken, address _userAddr) view public returns(uint256) {
        uint256 totalBaseTokenAmount;
        address[] memory quoteTokens = baseTokenPairs[_baseToken];
        for (uint256 i = 0; i < quoteTokens.length; i++) {
            address pairAddr = getPair[quoteTokens[i]][_baseToken];
            (uint256 baseTokenAmount,) = IBoboPair(pairAddr).getTotalHangingTokenAmount(_userAddr);
            totalBaseTokenAmount = totalBaseTokenAmount.add(baseTokenAmount);
        }
        return totalBaseTokenAmount;
    }

    function getClaimBaseTokenAmount(address _baseToken, address _userAddr) view public returns(uint256) {
        uint256 hangingBaseTokenAmount = boboFarmer.stakedWantTokens(_baseToken, _userAddr);
        uint256 baseTokenAmount = getTotalHangingTokenAmount(_baseToken, _userAddr);
        return hangingBaseTokenAmount.sub(baseTokenAmount);
    }
    // 此接口调用前提：需要在boboFarmer合约上为Factory合约开通权限
    function claimBaseToken(address _baseToken) public {
        uint256 amount = getClaimBaseTokenAmount(_baseToken, msg.sender);
        if (boboFarmer.tokenPidMap(_baseToken) > 0) {
            uint256 preBaseTokenAmount = IERC20(_baseToken).balanceOf(address(this));
            boboFarmer.withdraw(_baseToken, msg.sender, amount);
            uint256 newBaseTokenAmount = IERC20(_baseToken).balanceOf(address(this));
            IERC20(_baseToken).transfer(msg.sender, newBaseTokenAmount.sub(preBaseTokenAmount));
        }
    }
}