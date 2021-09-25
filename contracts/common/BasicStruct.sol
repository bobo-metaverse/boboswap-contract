// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.3
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./StructuredLinkedList.sol";

enum OrderStatus { Hanging, ManualCanceled, AMMDeal }
enum SwapPool {No, Mdex, Pancake, OneInch, Uniswap, SushiSwap, Dodo, QuickSwap}

struct NFTInfo {
    uint256 id;
    address owner;
    address pairAddr;       // the address of pair
    bool bBuyQuoteToken;    // true: buy quoteToken, false: sale quoteToken
    uint256 spotPrice;      // spot price of quoteToken
    uint256 inAmount;       // if bBuyQuoteToken is true, inAmount is the amount of base token, otherwise quote token
    uint256 minOutAmount;   // if bBuyQuoteToken is true, minOutAmount is the amount of quote token, otherwise base token
    uint256 outAmount;      // out amount in the end of the swap
    OrderStatus  status;
    string  comment;        // reason of unsettled
    uint256 delegateTime;   // 下单时间
    uint256 dealedTime;     //
    uint256 weight;
}

interface IOrderNFT is IERC721 {
    function transferOwnership(address newOwner) external;
    function addMinter(address _addMinter) external returns (bool);
    function mint(address _pairAddr, address _bookOwner, bool _bBuyQuoteToken, uint256 _spotPrice, uint256 _inAmount, uint256 _minOutAmount) external returns (uint256);
    function totalSupply() external returns(uint256);
    function getOrderInfo(uint256 _nftId) view external returns(NFTInfo memory nftInfo);
    function orderDetailIds(uint256 _nftId) view external returns(uint256[] memory ids);
    function getOrderDetailNumber(uint256 _nftId) view external returns(uint256);
    function sealNFT(uint256 _nftId, OrderStatus _status, uint256 _outAmount, string memory _comment) external;
    function getWeight(uint256 _nftId) view external returns(uint256 weight);
}



struct ResultInfo {
    uint256 totalAmountOut;
    uint256 totalULiquidity;

    SwapPool[] swapPools;
    address[] middleTokens;
    uint256[] partialAmountIns;
    uint256[] partialAmountOuts;
}


interface IBoboFund {
    function transferBobo(uint256 _boboAmount) external;
}

interface IBOBOToken is IERC20 {
    function mint(address _to, uint256 _amount) external returns(bool);
}
