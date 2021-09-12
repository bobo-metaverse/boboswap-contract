const BoboFarmer4BoboLP = artifacts.require("BoboMasterChef");
const BoboToken = artifacts.require("BoboToken");
const BoboFund = artifacts.require("BoboFund");

module.exports = async function(deployer) {
  var boboToken = await BoboToken.deployed();

  await deployer.deploy(BoboFarmer4BoboLP, BoboToken.address, BoboFund.address);
  var boboFarmer4BoboLP = await BoboFarmer4BoboLP.deployed();
  boboToken.addMinter(boboFarmer4BoboLP.address);

  var boboUsdtLP = '0x8F4Cd73B3ebEa35c2Ef108BB5b058b034B7757b5';
  boboFarmer4BoboLP.addPool(10, boboUsdtLP, false);
  boboFarmer4BoboLP.addPool(10, BoboToken.address, false);
  boboFarmer4BoboLP.setBoboPerBlock('1000000000000000000');
};