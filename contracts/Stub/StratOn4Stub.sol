// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


import "../common/BasicStruct.sol";

contract Strategy4Stub is Ownable, ReentrancyGuard {

    using SafeMath for uint256;
    using Strings for uint256;
    using SafeERC20 for IERC20;

    address public constant USDT = 0x40aF8F1383474BCb11496c302Ea309DBA24C8460; // decimals = 6
    address public constant USDC = 0x7B050D28603a33e036a642033B76D633d6574332; // decimals = 6
         
    mapping(address => uint256) public wantLockedTotalMap;  
    mapping(address => uint256) public sharesTotalMap; 

    // Transfer want tokens boboFarm -> strategy
    function deposit(uint256 _wantAmt, address _wantAddr) external returns (uint256) {
        IERC20(_wantAddr).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        // 
        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotalMap[_wantAddr] > 0) {
            sharesAdded = _wantAmt
                .mul(sharesTotalMap[_wantAddr])
                .div(wantLockedTotalMap[_wantAddr]);
        }
        sharesTotalMap[_wantAddr] = sharesTotalMap[_wantAddr].add(sharesAdded);
        wantLockedTotalMap[_wantAddr] = wantLockedTotalMap[_wantAddr].add(_wantAmt);
        
        return sharesAdded;
    }

    // Transfer want tokens strategy -> boboFarm
    function withdraw(uint256 _wantAmt, address _wantAddr) public onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0, "StratMaticSushi: _wantAmt <= 0");
        
        require(ERC20(_wantAddr).balanceOf(address(this)) >= _wantAmt, "StratMaticSushi: NOT enough.");
        uint256 realAmount = _wantAmt;        
        IERC20(_wantAddr).transfer(msg.sender, realAmount);

        // 2. 计算出用户占有的股份数，从总数中减去        
        uint256 sharesRemoved = realAmount.mul(sharesTotalMap[_wantAddr]).div(wantLockedTotalMap[_wantAddr]);
        if (sharesRemoved.mul(wantLockedTotalMap[_wantAddr]) < realAmount.mul(sharesTotalMap[_wantAddr])) {
            sharesRemoved = sharesRemoved.add(1);
        }
        if (sharesRemoved > sharesTotalMap[_wantAddr]) {
            sharesRemoved = sharesTotalMap[_wantAddr];
        }
        sharesTotalMap[_wantAddr] = sharesTotalMap[_wantAddr].sub(sharesRemoved);
        wantLockedTotalMap[_wantAddr] = wantLockedTotalMap[_wantAddr].sub(realAmount);

        return sharesRemoved;
    }

        // Main want token compounding function
    function earn(uint256 _earnAmt) external {
        IERC20(USDT).transferFrom(msg.sender, address(this), _earnAmt);
        IERC20(USDC).transferFrom(msg.sender, address(this), _earnAmt);

        wantLockedTotalMap[USDT] = wantLockedTotalMap[USDT].add(_earnAmt);
        wantLockedTotalMap[USDC] = wantLockedTotalMap[USDC].add(_earnAmt);
    }
}