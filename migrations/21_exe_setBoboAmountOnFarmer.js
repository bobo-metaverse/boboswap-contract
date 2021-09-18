const BoboFarmer = artifacts.require("BoboFarmer");
const StratMaticSushi = artifacts.require("StratMaticSushi");

// 设置挂单挖矿时BOBO的产量
module.exports = async function(deployer, network, accounts) {
  var boboFarmer = await BoboFarmer.deployed();
  boboFarmer.setBoboPerBlock('1000000000000000000');  // 1 bobo per block

};
