const BoboToken = artifacts.require("BoboToken");
const BoboFund = artifacts.require("BoboFund");
const BoboFarmer = artifacts.require("BoboFarmer");
const NewStratMaticSushi = artifacts.require("NewStratMaticSushi");

module.exports = async function(deployer, network, accounts) {
  var boboToken = await BoboToken.deployed();

  var boboFarmer = await BoboFarmer.deployed();

  await deployer.deploy(NewStratMaticSushi, boboToken.address, boboFarmer.address);
};
