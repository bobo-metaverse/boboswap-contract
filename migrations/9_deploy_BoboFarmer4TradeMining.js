const BoboFarmer4TradeMining = artifacts.require("BoboFarmer4TradeMining");

module.exports = async function(deployer) {
  await deployer.deploy(BoboFarmer4TradeMining);
};