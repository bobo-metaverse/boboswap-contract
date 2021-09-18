// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Minter.sol";
import "./BasicStruct.sol";
// 
contract OrderNFT is Minter, ERC721 {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    
    
    uint256 public nftId = 0;
    mapping(uint256 => NFTInfo) public id2NFTInfoMap;
    mapping(address => mapping(address => uint256[])) public owner2PairAddr2OrderIDsMap;   // 通过用户地址以及交易对地址获取其所有的订单
        
    event Mint(address indexed _to, uint256 _tokenId);
    
    constructor() ERC721("Bobo Order NFT", "BOT")  public {
    }        
    
    function mint(address _pairAddr, address bookOwner, bool _bBuyQuoteToken, uint256 _spotPrice, uint256 _inAmount, uint256 _minOutAmount) public onlyMinter returns (uint256) {
        nftId++;
        
        _safeMint(msg.sender, nftId);   // msg.sender is contract address of book pool, so the new NFT is belong to book pool at first, NOT bookOwner
        
        id2NFTInfoMap[nftId] = NFTInfo(nftId, bookOwner, _pairAddr, _bBuyQuoteToken, _spotPrice, _inAmount, _minOutAmount, 0, OrderStatus.Hanging, "", now, 0, 0);
        owner2PairAddr2OrderIDsMap[bookOwner][_pairAddr].push(nftId);    
            
        emit Mint(msg.sender, nftId);
        return nftId;
    }
    
    function sealNFT(uint256 _nftId, OrderStatus _status, uint256 _outAmount, string memory _comment) public onlyMinter {
        require( _exists(_nftId), "OrderNFT: nft is not exist.");
        id2NFTInfoMap[_nftId].status = _status;
        id2NFTInfoMap[_nftId].dealedTime = now;
        id2NFTInfoMap[_nftId].outAmount = _outAmount;
        id2NFTInfoMap[_nftId].comment = _comment;
        if (_status == OrderStatus.AMMDeal) {
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