// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Minter.sol";
import "./BasicStruct.sol";


enum OrderStatus { Hanging, ManualCanceled, Dealed }
enum SwapPool {No, Mdex, Pancake, OneInch, Uniswap, SushiSwap, Dodo, QuickSwap}

struct NFTInfo {
    uint256 id;
    uint256 parentId;
    address owner;
    address pairAddr;       // the address of pair
    bool bBuyQuoteToken;    // true: buy quoteToken, false: sale quoteToken
    uint256 spotPrice;      // spot price of quoteToken
    uint256 inAmount;       // if bBuyQuoteToken is true, inAmount is the amount of base token, otherwise quote token
    uint256 minOutAmount;   // if bBuyQuoteToken is true, minOutAmount is the amount of quote token, otherwise base token
    uint256 outAmount;      // out amount in the end of the swap
    OrderStatus  status;
    uint256 delegateTime;   // 下单时间
    uint256 dealedTime;     //
    uint256 weight;
}

contract OrderNFT is Minter, ERC721 {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    
    
    uint256 public nftId = 0;
    mapping(uint256 => NFTInfo) public id2NFTInfoMap;
    mapping(uint256 => uint256[]) public parentChildrenNFTMap;
        
    event Mint(address indexed _to, uint256 _tokenId);
    
    constructor() ERC721("Bobo Order NFT", "BOT")  public {
    }        
    
    function mint(uint256 _parentNFTId, address _pairAddr, address bookOwner, bool _bBuyQuoteToken, 
                  uint256 _spotPrice, uint256 _inAmount, uint256 _minOutAmount) public onlyMinter returns (uint256) {
        nftId++;
        
        _safeMint(msg.sender, nftId);   // msg.sender is contract address of book pool, so the new NFT is belong to book pool at first, NOT bookOwner
        
        id2NFTInfoMap[nftId] = NFTInfo(nftId, _parentNFTId, bookOwner, _pairAddr, _bBuyQuoteToken, _spotPrice, 
                                       _inAmount, _minOutAmount, 0, OrderStatus.Hanging, "", now, 0, 0);
        if (_parentNFTId > 0)
            parentChildrenNFTMap[_parentNFTId].push(nftId);    
            
        emit Mint(msg.sender, nftId);
        return nftId;
    }
    
    function sealNFT(uint256 _nftId, OrderStatus _status, uint256 _outAmount) public onlyMinter {
        require( _exists(_nftId), "OrderNFT: nft is not exist.");
        id2NFTInfoMap[_nftId].status = _status;
        id2NFTInfoMap[_nftId].dealedTime = now;
        id2NFTInfoMap[_nftId].outAmount = _outAmount;
        if (_status == OrderStatus.Dealed) {
            uint256 spanTime = now.sub(id2NFTInfoMap[_nftId].delegateTime);
            uint256 spanTimeFactor = spanTime == 0 ? 1 : sqrt(spanTime);
            uint256 dealedAmountU = id2NFTInfoMap[_nftId].bBuyQuoteToken ? id2NFTInfoMap[_nftId].inAmount : _outAmount;
            id2NFTInfoMap[_nftId].weight =  dealedAmountU.div(spanTimeFactor);
        }
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
    }

    function getOrderInfo(uint256 _nftId) view public returns(NFTInfo memory nftInfo) {
        require( _exists(_nftId), "OrderNFT: nft is not exist.");
        return id2NFTInfoMap[_nftId];
    }

    function getWeight(uint256 _nftId) view public returns(uint256 weight) {
        require( _exists(_nftId), "OrderNFT: nft is not exist.");
        NFTInfo memory nftInfo = id2NFTInfoMap[_nftId];
        return nftInfo.weight;
    }

    function getOrderDetailNumber(uint256 _nftId) view public returns(uint256) {
        return parentChildrenNFTMap[_nftId].length;
    }

    function sqrt(uint256 x) public pure returns(uint256) {
        uint z = (x + 1 ) / 2;
        uint y = x;
        while(z < y){
            y = z;
            z = ( x / z + z ) / 2;
        }
        return y;
    }
}