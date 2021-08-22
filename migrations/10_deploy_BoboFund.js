const BoboFund = artifacts.require("BoboFund");

module.exports = async function(deployer) {
  await deployer.deploy(BoboFund);
};