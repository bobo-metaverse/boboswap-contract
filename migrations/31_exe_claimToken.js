const BoboFarmer = artifacts.require("BoboFarmer");
const StratMaticSushi = artifacts.require("NewStratMaticSushi");
const ERC20 = artifacts.require("ERC20");
      
const USDT = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F";
const USDC = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
const userAddr = '0x177CfCD9286B30D27122e9b308140E14Bc353a05';
module.exports = async function(deployer, network, accounts) {
  var boboFarmer = await BoboFarmer.deployed();
  var stratMaticSushi = await StratMaticSushi.deployed();

  var stakedAmount = await boboFarmer.stakedWantTokens(USDT, userAddr);
  console.log('USDT staked:', stakedAmount.toString(10));
  stakedAmount = await boboFarmer.stakedWantTokens(USDC, userAddr);
  console.log('USDC staked:', stakedAmount.toString(10));

  var balanceInfo = await stratMaticSushi.getBalances(USDT, USDC);
  console.log('USDT:', balanceInfo[0].toString(10), 'USDT:', balanceInfo[1].toString(10));

  var usdt = await ERC20.at(USDT);
  var usdtAmount = await usdt.balanceOf(StratMaticSushi.address);
  console.log('usdtAmount:', usdtAmount.toString(10));

  var usdc = await ERC20.at(USDC);
  var usdcAmount = await usdc.balanceOf(StratMaticSushi.address);
  console.log('usdcAmount:', usdcAmount.toString(10));
};
