const BoboFarmer4BoboLP = artifacts.require("BoboMasterChef");
const BoboToken = artifacts.require("BoboToken");
const BoboFund = artifacts.require("BoboFund");

module.exports = async function(deployer) {
  var boboToken = await BoboToken.deployed();

  await deployer.deploy(BoboFarmer4BoboLP, BoboToken.address, BoboFund.address);
  var boboFarmer4BoboLP = await BoboFarmer4BoboLP.deployed();
  boboToken.addMinter(boboFarmer4BoboLP.address);
};