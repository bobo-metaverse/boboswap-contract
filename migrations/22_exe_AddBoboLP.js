const BoboFarmer4BoboLP = artifacts.require("BoboMasterChef");
const BoboToken = artifacts.require("BoboToken");

module.exports = async function(deployer) {
  var boboFarmer4BoboLP = await BoboFarmer4BoboLP.deployed();

  // 以下部分可等挂单挖矿产生BoboToken后，在QuickSwap上添加流动性，再进行操作
  var boboUsdtLP = '';  // bobo-usdt pair on quickswap
  boboFarmer4BoboLP.addPool(10, boboUsdtLP, false);
  boboFarmer4BoboLP.addPool(10, BoboToken.address, false);
  boboFarmer4BoboLP.setBoboPerBlock('1000000000000000000');  // 1 BOBO per Block
};