// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../common/BasicStruct.sol";

contract EXManager is Ownable {
    using SafeMath for uint256;

    uint256 constant public vipBaseline = 10;
    mapping(address => uint256) public usableTradeCountMap;  // 用户剩余可用的交易次数
    
    uint256 public maxFreePointPerAccount = 10;
    uint256 public minDepositValue = 1e18;
    uint256 public orderCountPerToken = 100;    // 最小充值金额对应的可交易次数
    uint256 public maxNumberPerAMMSwap = 10;    // 一次最多可成交的AMM订单数
    address public feeEarnedContract;           // 项目方抽成资金需打入此合约中，此合约可关联矿池
    mapping(address => uint256) public tokenInvestRateMap;   // 各资产抵押率，用户挂单时，需要抵押到矿池中的资产比例
    mapping(address => bool) public _auth;
    mapping(address => uint256) public accountFreePointMap;
    mapping(address => uint256) public tokenMinAmountMap;
    uint256 public stopFreeBlockNum;

    modifier onlyAuth {
        require(_auth[msg.sender], "no permission");
        _;
    }
    
    constructor () public {
        usableTradeCountMap[msg.sender] = 10000;
        stopFreeBlockNum = block.number + 300000;
    }
    
    function addAuth(address _addr) public onlyOwner {
        _auth[_addr] = true;
    }

    function removeAuth(address _addr) public onlyOwner {
        _auth[_addr] = false;
    }
    
    function setTokenInvestRate(address _tokenAddr, uint256 _investRate) public onlyOwner {
        require(_investRate <= 100, "EXManager: invest rate is too large.");
        tokenInvestRateMap[_tokenAddr] = _investRate;
    }

    
    function setTokenMinAmount(address _tokenAddr, uint256 _minAmount) public onlyOwner {
        tokenMinAmountMap[_tokenAddr] = _minAmount;
    }
    
    function setOrderCountPerToken(uint256 _orderCountPerToken) public onlyOwner {
        orderCountPerToken = _orderCountPerToken;
    }
    
    function setMaxNumberPerAMMSwap(uint256 _maxNumber) public onlyOwner {
        maxNumberPerAMMSwap = _maxNumber;
    }
    
    function setFeeEarnedContract(address _feeEarnedContract) public onlyOwner {
        uint256 size;
        assembly {
            size := extcodesize(_feeEarnedContract)
        }
        require(size > 0, "EXManager: Only support contract address.");
        feeEarnedContract = _feeEarnedContract;
    }
    
    // 充值平台币，购买点数，需要按整数充值
    function buyTradePoints() payable public {
        require(msg.value >= minDepositValue, "EXManager: Deposit must be bigger than minDepositValue.");
        uint256 baseAmount = msg.value.div(minDepositValue);
        uint256 leftAmount = msg.value.mod(minDepositValue);
        usableTradeCountMap[msg.sender] = usableTradeCountMap[msg.sender].add(baseAmount.mul(orderCountPerToken));
        if (leftAmount > 0)
            msg.sender.transfer(leftAmount);
    }

    function addTradePoints(address _userAddr, uint256 _burnedNumber) public onlyOwner {
        usableTradeCountMap[_userAddr] = usableTradeCountMap[_userAddr].add(_burnedNumber);
    }

    function burnTradePoints(address _userAddr, uint256 _burnedNumber) public onlyAuth returns(bool) {
        if (accountFreePointMap[_userAddr] < maxFreePointPerAccount && block.number < stopFreeBlockNum) {
            accountFreePointMap[_userAddr]++;
            return true;
        }
        if (usableTradeCountMap[_userAddr] < _burnedNumber) {
            return false;
        }
        usableTradeCountMap[_userAddr] = usableTradeCountMap[_userAddr].sub(_burnedNumber);
        return true;
    }
    
    function setStopFreeBlockNum(uint256 _blockNum) public onlyOwner {
        stopFreeBlockNum = _blockNum;
    }
    
    function withdraw() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }
}