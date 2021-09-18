// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
        
import "./common/BasicStruct.sol";
import "./SwapInterfaces.sol";

contract BoboRouter is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    address public constant quickSwapFactory = 0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32;
    address public constant quickSwapRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff; 
    
    address public constant sushiSwapFactory = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
    address public constant sushiSwapRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    
    address public constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;   // decimals = 6
    address public constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;   // decimals = 6
    address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // decimals = 18
    address public constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; // decimals = 18
    address public constant QUICK = 0x831753DD7087CaC61aB5644b308642cc1c33Dc13; // decimals = 18

    address public constant burnAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant FACTOR = 1e8;
    AggregatorV3Interface internal wmaticPriceFeed = AggregatorV3Interface(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0);
    AggregatorV3Interface internal wethPriceFeed = AggregatorV3Interface(0xF9680D99D6C9589e2a93a78A04A279e509205945);
    AggregatorV3Interface internal quickPriceFeed = AggregatorV3Interface(0xa058689f4bCa95208bba3F265674AE95dED75B6D);
    mapping(address => AggregatorV3Interface) public tokenAggregatorMap;
    
    address[] public middleTokens = [USDT, USDC, WMATIC, WETH, QUICK];
    uint256 public MinLiquidityValue = 1e11;  // 流动性>=100000U 

    uint256 public feeRate = 0;
    uint256 public constant BaseRate = 10000;

    EnumerableSet.AddressSet private orderOwnerSet;
    
    struct PathsInfo {
        address[] tokens;
        uint256[] minUValues;
        uint256 pathCount;
    }
    
    constructor() public {
        tokenAggregatorMap[WMATIC] = wmaticPriceFeed;
        tokenAggregatorMap[WETH] = wethPriceFeed;
        tokenAggregatorMap[QUICK] = quickPriceFeed;
    }

    function addMiddleTokenAndAggregator(address _middleToken, address _aggregator) public onlyOwner {
        require(tokenAggregatorMap[_middleToken] == AggregatorV3Interface(address(0)), "BoboRouter: middle token EXIST.");
        middleTokens.push(_middleToken);
        tokenAggregatorMap[_middleToken] = AggregatorV3Interface(_aggregator);
    }
    
    function isUToken(address token) public pure returns(bool) {
        return token == USDT || token == USDC;
    }
    
    function getBaseTokenPriceOnQuickSwap(address baseToken) public view returns(uint256) {
       (address token0, ) = USDC < baseToken ? (USDC, baseToken) : (baseToken, USDC);
       address pairAddr = ICommonFactory(quickSwapFactory).getPair(USDC, baseToken);
       (uint256 reserveA, uint256 reserveB,) = ICommonPair(pairAddr).getReserves();
       uint256 decimals = ERC20(baseToken).decimals();
       uint256 decimalsGap = decimals - ERC20(USDC).decimals();
       return token0 == USDC ? reserveA.mul(FACTOR).mul(10**decimalsGap).div(reserveB) : reserveB.mul(FACTOR).mul(10**decimalsGap).div(reserveA);
    }
    
    function getBaseTokenPriceOnChainlink(address baseToken) public view returns(uint256) {
        AggregatorV3Interface priceFeed = tokenAggregatorMap[baseToken];
       (, int price,,,) = priceFeed.latestRoundData();
        return uint256(price);
    }
    
    function getReserves(address factoryAddr, address token0, address token1) public view returns(uint256, uint256) {
        address pairAddr = ICommonFactory(factoryAddr).getPair(token0, token1);
        if (pairAddr == address(0)) return (0, 0);
        (uint256 reserveA, uint256 reserveB,) = ICommonPair(pairAddr).getReserves();
        return (reserveA, reserveB);
    }
    
    function getMinUValue(address factoryAddr, address[] memory path) public view returns(uint256) {
       uint256 minUValue = uint256(-1);
       
       for (uint256 i = 0; i < path.length - 1; i++) {
           uint256 tmpUValue;
           (address token0, address token1) = path[i] < path[i + 1] ? (path[i], path[i + 1]) : (path[i + 1], path[i]);
           (uint256 reserveA, uint256 reserveB) = getReserves(factoryAddr, token0, token1);
           if (isUToken(token0)) {
               tmpUValue = reserveA;
           } else if (isUToken(token1)) {
               tmpUValue = reserveB;
           } else {
               (address baseToken, uint256 reserve) = tokenAggregatorMap[token0] != AggregatorV3Interface(address(0)) ? (token0, reserveA) : (token1, reserveB); 
               uint256 baseTokenPriceOnQuickSwap = getBaseTokenPriceOnQuickSwap(baseToken);
               uint256 baseTokenPriceOnChainlink = getBaseTokenPriceOnChainlink(baseToken);
               uint256 gap = 0;
               if (baseTokenPriceOnQuickSwap > baseTokenPriceOnChainlink) {
                   gap = baseTokenPriceOnQuickSwap.sub(baseTokenPriceOnChainlink).mul(1000).div(baseTokenPriceOnChainlink);
               } else {
                   gap = baseTokenPriceOnChainlink.sub(baseTokenPriceOnQuickSwap).mul(1000).div(baseTokenPriceOnQuickSwap);
               }
               require(gap <= 100, "BoboRouter: matic'price gap between chainlink and quickswap is large than 10%.");
               uint256 decimals = ERC20(baseToken).decimals();
               uint256 decimalsGap = decimals - ERC20(USDC).decimals();
               tmpUValue = baseTokenPriceOnChainlink.mul(reserve).div(FACTOR).div(10**decimalsGap);
           }
           if (minUValue > tmpUValue) minUValue = tmpUValue;
       }
       return minUValue;
    }
    
    function getPaths(address factoryAddr, address inToken, address outToken) public view returns(PathsInfo memory pathsInfo) {
        pathsInfo = PathsInfo(new address[](middleTokens.length), new uint256[](middleTokens.length), 0);
        for (uint256 i = 0; i < middleTokens.length; i++) {
            if (middleTokens[i] == inToken || middleTokens[i] == outToken) continue;
            
            address[] memory path = new address[](3);
            path[0] = inToken; 
            path[1] = middleTokens[i]; 
            path[2] = outToken;
            uint256 minUValue = getMinUValue(factoryAddr, path);
            if (minUValue >= MinLiquidityValue) {
                pathsInfo.tokens[pathsInfo.pathCount] = middleTokens[i]; 
                pathsInfo.minUValues[pathsInfo.pathCount] = minUValue;
                pathsInfo.pathCount++;
            }
        }
    }

    function caculateTotalLiquidity(address inToken, address outToken) public view returns(uint256 totalULiquidity) {
        PathsInfo memory quickSwapPathsInfo = getPaths(quickSwapFactory, inToken, outToken);
        PathsInfo memory sushiSwapPathsInfo = getPaths(sushiSwapFactory, inToken, outToken);
        
        address[] memory path = new address[](2);
        path[0] = inToken;
        path[1] = outToken;
        
        uint256 quickSwapMinUValue = getMinUValue(quickSwapFactory, path);
        uint256 sushiSwapMinUValue = getMinUValue(sushiSwapFactory, path);
        
        if (quickSwapMinUValue > MinLiquidityValue) {
            totalULiquidity = totalULiquidity.add(quickSwapMinUValue);
        }
        if (sushiSwapMinUValue > MinLiquidityValue) {
            totalULiquidity = totalULiquidity.add(sushiSwapMinUValue);
        }
        
        for (uint256 i = 0; i < quickSwapPathsInfo.pathCount; i++) {
            totalULiquidity = totalULiquidity.add(quickSwapPathsInfo.minUValues[i]);
        }
        for (uint256 i = 0; i < sushiSwapPathsInfo.pathCount; i++) {
            totalULiquidity = totalULiquidity.add(sushiSwapPathsInfo.minUValues[i]);
        }
        totalULiquidity = totalULiquidity.mul(2);
    }
    
    function getBestSwapPath(address inToken, address outToken, uint256 amountIn) public view returns(uint256[] memory amountsOut, ResultInfo memory bestResultInfo) {
        amountsOut = new uint256[](3);
        
        address[] memory path = new address[](2);
        path[0] = inToken;
        path[1] = outToken;
        
        //ResultInfo memory bestResultInfo;
        uint256 totalAmountOut = 0;
        
        (ResultInfo memory quickSwapResultInfo) = caculateOneDexAmountOut(quickSwapFactory, inToken, outToken, amountIn);
        amountsOut[0] = quickSwapResultInfo.totalAmountOut;
        if (quickSwapResultInfo.totalAmountOut > totalAmountOut) {
            bestResultInfo = quickSwapResultInfo;
            totalAmountOut = quickSwapResultInfo.totalAmountOut;
        }
        
        (ResultInfo memory sushiSwapResultInfo) = caculateOneDexAmountOut(sushiSwapFactory, inToken, outToken, amountIn);
        amountsOut[1] = sushiSwapResultInfo.totalAmountOut;
        if (sushiSwapResultInfo.totalAmountOut > totalAmountOut) {
            bestResultInfo = sushiSwapResultInfo;
            totalAmountOut = sushiSwapResultInfo.totalAmountOut;
        }
        
        ResultInfo memory allResultInfo = caculateAmountOut(inToken, outToken, amountIn);
        amountsOut[2] = allResultInfo.totalAmountOut;
        if (allResultInfo.totalAmountOut > totalAmountOut) {
            bestResultInfo = allResultInfo;
            totalAmountOut = allResultInfo.totalAmountOut;
        }
    }

    function caculateOneDexAmountOut(address dexFactory, address inToken, address outToken, uint256 amountIn) public view returns(ResultInfo memory resultInfo) {
        PathsInfo memory pathsInfo = getPaths(dexFactory, inToken, outToken);
        address[] memory path = new address[](2);
        path[0] = inToken;
        path[1] = outToken;
        
        uint256 minUValue = getMinUValue(dexFactory, path);
        
        uint256 totalULiquidity = 0;
        if (minUValue > MinLiquidityValue) {
            totalULiquidity = totalULiquidity.add(minUValue);
        }
        
        for (uint256 i = 0; i < pathsInfo.pathCount; i++) {
            totalULiquidity = totalULiquidity.add(pathsInfo.minUValues[i]);
        }
        
        uint256 partialAmountIn;
        uint256 totalAmountOut = 0;
        
        resultInfo.swapPools = new SwapPool[](4);
        resultInfo.middleTokens = new address[](4);
        resultInfo.partialAmountIns = new uint256[](4);
        resultInfo.partialAmountOuts = new uint256[](4);
        uint256 count = 0;
        address routerAddr = dexFactory == quickSwapFactory ? quickSwapRouter : sushiSwapRouter;
        SwapPool middleTokeType = dexFactory == quickSwapFactory ? SwapPool.QuickSwap : SwapPool.SushiSwap;
        
        if (minUValue > MinLiquidityValue) {
            partialAmountIn = minUValue.mul(amountIn).div(totalULiquidity);
            uint256 amountOut = getAmountOut(routerAddr, partialAmountIn, path);
            
            resultInfo.swapPools[count] = middleTokeType;
            resultInfo.middleTokens[count] = address(0); 
            resultInfo.partialAmountIns[count] = partialAmountIn;
            resultInfo.partialAmountOuts[count] = amountOut;
            totalAmountOut = totalAmountOut.add(amountOut);
            count++;
        }
        
        address[] memory tmpPath = new address[](3);
        for (uint256 i = 0; i < pathsInfo.pathCount; i++) {
            tmpPath[0] = inToken;
            tmpPath[1] = pathsInfo.tokens[i];
            tmpPath[2] = outToken;
            partialAmountIn = pathsInfo.minUValues[i] * amountIn / totalULiquidity;
            uint256 amountOut = getAmountOut(routerAddr, partialAmountIn, tmpPath);
            
            resultInfo.swapPools[count] = middleTokeType;
            resultInfo.middleTokens[count] = pathsInfo.tokens[i]; 
            resultInfo.partialAmountIns[count] = partialAmountIn;
            resultInfo.partialAmountOuts[count] = amountOut;
            totalAmountOut = totalAmountOut.add(amountOut);
            count++;
        }
        resultInfo.totalAmountOut = totalAmountOut;
        resultInfo.totalULiquidity = totalULiquidity;
    }
        
    function caculateAmountOut(address inToken, address outToken, uint256 amountIn) public view returns(ResultInfo memory resultInfo) {
        PathsInfo memory quickSwapPathsInfo = getPaths(quickSwapFactory, inToken, outToken);
        PathsInfo memory sushiSwapPathsInfo = getPaths(sushiSwapFactory, inToken, outToken);
        
        address[] memory path = new address[](2);
        path[0] = inToken;
        path[1] = outToken;
        
        uint256 quickSwapMinUValue = getMinUValue(quickSwapFactory, path);
        uint256 sushiSwapMinUValue = getMinUValue(sushiSwapFactory, path);
        
        uint256 totalULiquidity = 0;
        if (quickSwapMinUValue > MinLiquidityValue) {
            totalULiquidity = totalULiquidity.add(quickSwapMinUValue);
        }
        if (sushiSwapMinUValue > MinLiquidityValue) {
            totalULiquidity = totalULiquidity.add(sushiSwapMinUValue);
        }
        
        for (uint256 i = 0; i < quickSwapPathsInfo.pathCount; i++) {
            totalULiquidity = totalULiquidity.add(quickSwapPathsInfo.minUValues[i]);
        }
        for (uint256 i = 0; i < sushiSwapPathsInfo.pathCount; i++) {
            totalULiquidity = totalULiquidity.add(sushiSwapPathsInfo.minUValues[i]);
        }
        
        
        uint256 partialAmountIn;
        uint256 totalAmountOut = 0;
        
        resultInfo.swapPools = new SwapPool[](10);
        resultInfo.middleTokens = new address[](10);
        resultInfo.partialAmountIns = new uint256[](10);
        resultInfo.partialAmountOuts = new uint256[](10);
        uint256 count = 0;
        
        if (quickSwapMinUValue > MinLiquidityValue) {
            partialAmountIn = quickSwapMinUValue.mul(amountIn).div(totalULiquidity);
            uint256 amountOut = getAmountOut(quickSwapRouter, partialAmountIn, path);
            
            resultInfo.swapPools[count] = SwapPool.QuickSwap;
            resultInfo.middleTokens[count] = address(0); 
            resultInfo.partialAmountIns[count] = partialAmountIn;
            resultInfo.partialAmountOuts[count] = amountOut;
            totalAmountOut = totalAmountOut.add(amountOut);
            count++;
        }
        
        if (sushiSwapMinUValue > MinLiquidityValue) {
            partialAmountIn = sushiSwapMinUValue.mul(amountIn).div(totalULiquidity);
            uint256 amountOut = getAmountOut(sushiSwapRouter, partialAmountIn, path);
            
            resultInfo.swapPools[count] = SwapPool.SushiSwap;
            resultInfo.middleTokens[count] = address(0); 
            resultInfo.partialAmountIns[count] = partialAmountIn;
            resultInfo.partialAmountOuts[count] = amountOut;
            totalAmountOut = totalAmountOut.add(amountOut);
            count++;
        }
        
        address[] memory tmpPath = new address[](3);
        for (uint256 i = 0; i < quickSwapPathsInfo.pathCount; i++) {
            tmpPath[0] = inToken;
            tmpPath[1] = quickSwapPathsInfo.tokens[i];
            tmpPath[2] = outToken;
            partialAmountIn = quickSwapPathsInfo.minUValues[i] * amountIn / totalULiquidity;
            uint256 amountOut = getAmountOut(quickSwapRouter, partialAmountIn, tmpPath);
            
            resultInfo.swapPools[count] = SwapPool.QuickSwap;
            resultInfo.middleTokens[count] = quickSwapPathsInfo.tokens[i]; 
            resultInfo.partialAmountIns[count] = partialAmountIn;
            resultInfo.partialAmountOuts[count] = amountOut;
            totalAmountOut = totalAmountOut.add(amountOut);
            count++;
        }
        for (uint256 i = 0; i < sushiSwapPathsInfo.pathCount; i++) {
            tmpPath[0] = inToken;
            tmpPath[1] = sushiSwapPathsInfo.tokens[i];
            tmpPath[2] = outToken;
            partialAmountIn = sushiSwapPathsInfo.minUValues[i] * amountIn / totalULiquidity;
            uint256 amountOut = getAmountOut(sushiSwapRouter, partialAmountIn, tmpPath);
            
            resultInfo.swapPools[count] = SwapPool.SushiSwap;
            resultInfo.middleTokens[count] = sushiSwapPathsInfo.tokens[i]; 
            resultInfo.partialAmountIns[count] = partialAmountIn;
            resultInfo.partialAmountOuts[count] = amountOut;
            totalAmountOut = totalAmountOut.add(amountOut);
            count++;
        }
        resultInfo.totalAmountOut = totalAmountOut;
        resultInfo.totalULiquidity = totalULiquidity;
    }
    
    function getAmountOut(address routerAddr, uint256 partialAmountIn, address[] memory path) public view returns(uint256) {
        uint256[] memory amountsOut = ICommonRouter(routerAddr).getAmountsOut(partialAmountIn, path);
        return amountsOut[path.length - 1];
    }
    
    function convertThreePath(address[3] memory path) private pure returns(address[] memory newPath) {
        newPath = new address[](path.length);
        for (uint256 i = 0; i < path.length; i++) {
            newPath[i] = path[i];
        }
    }
    
    function convertTwoPath(address[2] memory path) private pure returns(address[] memory newPath) {
        newPath = new address[](path.length);
        for (uint256 i = 0; i < path.length; i++) {
            newPath[i] = path[i];
        }
    }
    
    function exeSwap(ResultInfo memory _bestSwapInfo, address _inToken, address _outToken, uint256 _amountIn) private returns(uint256 totalAmountOut) {
        IERC20(_inToken).transferFrom(msg.sender, address(this), _amountIn);
        
        SwapPool[] memory swapPools = _bestSwapInfo.swapPools;
        for (uint256 i = 0; i < swapPools.length; i++) {
            if (swapPools[i] == SwapPool.No) break;
            
            address[] memory path = _bestSwapInfo.middleTokens[i] == address(0) ? convertTwoPath([_inToken, _outToken]) :convertThreePath([_inToken, _bestSwapInfo.middleTokens[i], _outToken]);
            uint256 partialAmountIn = (i == swapPools.length - 1) ? IERC20(_inToken).balanceOf(address(this)) : _bestSwapInfo.partialAmountIns[i];
            uint256 partialAmountOut = _bestSwapInfo.partialAmountOuts[i];
            if (swapPools[i] == SwapPool.QuickSwap) {
                IERC20(_inToken).approve(quickSwapRouter, partialAmountIn);
                uint256[] memory amountOuts = ICommonRouter(quickSwapRouter).swapExactTokensForTokens(partialAmountIn, partialAmountOut, path, address(this), now);
                totalAmountOut = totalAmountOut.add(amountOuts[amountOuts.length - 1]);
            } else if (swapPools[i] == SwapPool.SushiSwap) {
                IERC20(_inToken).approve(sushiSwapRouter, partialAmountIn);
                uint256[] memory amountOuts = ICommonRouter(sushiSwapRouter).swapExactTokensForTokens(partialAmountIn, partialAmountOut, path, address(this), now);
                totalAmountOut = totalAmountOut.add(amountOuts[amountOuts.length - 1]);
            } 
        }
    }

    function swap(address _inToken, address _outToken, uint256 _amountIn, uint256 _minAmountOut, address _orderOwner) external {
        (, ResultInfo memory bestResultInfo) = getBestSwapPath(_inToken, _outToken, _amountIn);
        if (bestResultInfo.totalAmountOut < _minAmountOut) return;

        uint256 totalAmountOut = exeSwap(bestResultInfo, _inToken, _outToken, _amountIn);
        uint256 profitAmount = totalAmountOut.sub(_minAmountOut).mul(feeRate).div(BaseRate);

        IERC20(_outToken).transfer(msg.sender, totalAmountOut.sub(profitAmount));
        orderOwnerSet.add(_orderOwner);
    }

    function withdrawToken(address _tokenAddr) public onlyOwner {
        ERC20(_tokenAddr).transfer(msg.sender, ERC20(_tokenAddr).balanceOf(address(this)));
    }

    function setFeeRate(uint256 _feeRate) public onlyOwner {
        feeRate = _feeRate;
    }
 }