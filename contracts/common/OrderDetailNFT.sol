// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Minter.sol";
import "./BasicStruct.sol";

struct NFTDetailInfo {
    uint256 id;
    uint256 time;            // 吃单时间
    uint256 inAmount;        // inAmount指哪种代币，根据订单类型而定，如果是卖单，则inAmount是买入的那个基础token，否则就是被卖出的那个token
    uint256 outAmount;
    uint256 orderNFTId;      // 主订单编号
    SwapPool swapPool;
    address[3] path;          // 交易路径
}

interface IOrderDetailNFT is IERC721 {
    function transferOwnership(address newOwner) external;
    function addMinter(address _addMinter) external returns (bool);
    function mint(address _nftOwner, uint256 _inAmount, uint256 _outAmount, uint256 _orderNFTId, SwapPool _swapPool, address[3] memory _path) external returns (uint256);
    function totalSupply() external returns(uint256);
    function getOrderDetailInfo(uint256 _nftId) view external returns(NFTDetailInfo memory nftDetailInfo);
}

contract OrderDetailNFT is Minter, ERC721 {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    
    uint256 public nftId = 0;
    IOrderNFT public orderNFT;
    mapping(uint256 => NFTDetailInfo) public id2NFTDetailInfoMap;
    
    event Mint(address indexed _to, uint256 _tokenId);
    
    constructor() ERC721("Bobo Order Detail", "BOT-D")  public {
    }        
    
    function setOrderNFT(address _orderNFT) public onlyOwner {
        orderNFT = IOrderNFT(_orderNFT);
    }
    
    function mint(address _nftOwner, uint256 _inAmount, uint256 _outAmount, uint256 _orderNFTId, SwapPool _swapPool, address[3] memory _path) public onlyMinter returns (uint256) {
        nftId++;
        
        _safeMint(_nftOwner, nftId);
        
        id2NFTDetailInfoMap[nftId] = NFTDetailInfo(nftId, now, _inAmount, _outAmount, _orderNFTId, _swapPool, _path);
        
        //orderNFT.bindDetailNFT(_orderNFTId, nftId);
        
        emit Mint(_nftOwner, nftId);
        return nftId;
    }

    function getOrderDetailInfo(uint256 _nftId) view public returns(NFTDetailInfo memory nftDetailInfo) {
        require( _exists(_nftId), "OrderDetailNFT: nft is not exist.");
        return id2NFTDetailInfoMap[_nftId];
    }
}