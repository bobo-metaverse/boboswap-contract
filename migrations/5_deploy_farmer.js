
const BoboToken = artifacts.require("BoboToken");
const BoboFund = artifacts.require("BoboFund");
const BoboFarmer = artifacts.require("BoboFarmer");
const StratMaticSushi = artifacts.require("StratMaticSushi");

module.exports = async function(deployer, network, accounts) {
  var boboToken = await BoboToken.deployed();

  await deployer.deploy(BoboFund);
  var boboFund = await BoboFund.deployed();

  await deployer.deploy(BoboFarmer, boboToken.address, boboFund.address);
  var boboFarmer = await BoboFarmer.deployed();
  // boboFarmer.setBoboPerBlock(10);  // 试运营阶段不挖bobo，待正式运营后开通

  boboToken.addMinter(boboFarmer.address);

  await deployer.deploy(StratMaticSushi, boboToken.address, boboFarmer.address);
  var stratMaticSushi = await StratMaticSushi.deployed();

  var USDT = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
  var USDC = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
  boboFarmer.add(10, USDT, false, stratMaticSushi.address);
  boboFarmer.add(10, USDC, false, stratMaticSushi.address);
};
