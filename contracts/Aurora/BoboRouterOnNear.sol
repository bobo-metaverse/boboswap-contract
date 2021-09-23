// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
        
import "../common/BasicStruct.sol";

contract BoboRouter is Ownable {
    using SafeMath for uint256;
    //using EnumerableSet for EnumerableSet.AddressSet;

    // address public constant USDT = 0x4988a896b1227218e4a686fde5eabdcabd91571f; // decimals = 6
    // address public constant USDC = 0xb12bfca5a55806aaf64e99521918a4bf0fc40802; // decimals = 6
    // address public constant UNI = 0x1bc741235ec0ee86ad488fa49b69bb6c823ee7b7; // decimals = 18

    constructor() public {
    }

    function getBaseAmountOut(address inToken, address outToken, uint256 amountIn) public view returns(uint256 amountOut) {
        uint256 reserve0 = ERC20(inToken).balanceOf(address(this));
        uint256 reserve1 = ERC20(outToken).balanceOf(address(this));
        return reserve1.sub(reserve0.mul(reserve1).div(reserve0.add(amountIn)));
    }
    
    function swap(address _inToken, address _outToken, uint256 _amountIn, uint256 _minAmountOut, address _orderOwner) external {
        uint256 amountOut = getBaseAmountOut(_inToken, _outToken, _amountIn);
        if (amountOut >= _minAmountOut) {
            IERC20(_inToken).transferFrom(msg.sender, address(this), _amountIn);
            IERC20(_outToken).transfer(msg.sender, amountOut);
        }
    }

    function withdrawToken(address _tokenAddr) public onlyOwner {
        ERC20(_tokenAddr).transfer(msg.sender, ERC20(_tokenAddr).balanceOf(address(this)));
    }
 }