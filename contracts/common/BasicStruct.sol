// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "./MathEX.sol";
import "./StructuredLinkedList.sol";

enum OrderStatus { Hanging, ManualCanceled, AMMDeal, Exception }
enum SwapPool {No, Mdex, Pancake, OneInch, Uniswap, SushiSwap, Dodo, QuickSwap}

struct NFTInfo {
    uint256 id;
    address owner;
    address pairAddr;       // the address of pair
    bool bBuyQuoteToken;        // true: buy token0, false: sale token0
    uint256 spotPrice;      // spot price of token1/token0，此值已经乘上了10**token0Decmials (每个token0价值多少token1，token0用了最大单位, token1用了最小单位)
    uint256 inAmount;       // if bBuyQuoteToken is true, inAmount is the amount of base token, otherwise quote token
    uint256 minOutAmount;   // if bBuyQuoteToken is true, minOutAmount is the amount of quote token, otherwise base token
    uint256 outAmount;      // out amount in the end of the swap
    OrderStatus  status;
    string  comment;        // reason of unsettled
    uint256 delegateTime;   // 下单时间
    uint256 dealedTime;     //
}

struct NFTDetailInfo {
    uint256 id;
    uint256 time;            // 吃单时间
    uint256 inAmount;        // inAmount指哪种代币，根据订单类型而定，如果是卖单，则inAmount是买入的那个基础token，否则就是被卖出的那个token
    uint256 outAmount;
    uint256 orderNFTId;      // 主订单编号
    // uint256 matchedOrderId;  // 同本订单成交的那个订单编号，matchedOrderId和exchangeObject两者必定一个为0，一个有值
    // 本订单交易对象，AMM中的router地址，或者某个个人账户地址，router地址可以是不同的uniswapV2一族的交易合约，如mdex, dodo, pancake, 1inch, uniswap, sushiswap等等
    // 如果address为0，表示被本订单薄自己吃了
    // address exchangeObject;
    SwapPool swapPool;
    address[] path;          // 交易路径
}

interface  IStructureInterface {
    function getValue(uint256 _id) external view returns (uint256);
}


interface IOrderNFT is IERC721 {
    function transferOwnership(address newOwner) external;
    function bindDetailNFT(uint256 _nftId, uint256 detailNFTId) external;
    function addMinter(address _addMinter) external returns (bool);
    function mint(address _pairAddr, address _bookOwner, bool _bBuyQuoteToken, uint256 _spotPrice, uint256 _inAmount, uint256 _minOutAmount) external returns (uint256);
    function totalSupply() external returns(uint256);
    function getOrderInfo(uint256 _nftId) view external returns(NFTInfo memory nftInfo);
    function orderDetailIds(uint256 _nftId) view external returns(uint256[] memory ids);
    function getOrderDetailNumber(uint256 _nftId) view external returns(uint256);
    function sealNFT(uint256 _nftId, OrderStatus _status, uint256 _outAmount, string memory _comment) external;
}

interface IOrderDetailNFT is IERC721 {
    function transferOwnership(address newOwner) external;
    function addMinter(address _addMinter) external returns (bool);
    function mint(address _nftOwner, uint256 _inAmount, uint256 _outAmount, uint256 _orderNFTId, SwapPool _swapPool, address[] memory _path) external returns (uint256);
    function totalSupply() external returns(uint256);
    function getOrderDetailInfo(uint256 _nftId) view external returns(NFTDetailInfo memory nftDetailInfo);
}

struct ResultInfo {
    uint256 totalAmountOut;
    uint256 totalULiquidity;

    SwapPool[] types;
    address[] middleTokens;
    uint256[] partialAmountIns;
    uint256[] partialAmountOuts;
}

interface IBoboRouter {
    function getBestSwapPath(address inToken, address outToken, uint256 amountIn) external view returns(uint256[] memory amountsOut, ResultInfo memory bestResultInfo);
    function swap(ResultInfo memory _bestSwapInfo, address _inToken, address _outToken, uint256 _amountIn, address _receiver) external returns(uint256);
}
