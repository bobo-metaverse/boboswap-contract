const BoboSwapTester = artifacts.require("BoboSwapTester");

module.exports = async function(deployer) {
  await deployer.deploy(BoboSwapTester);
};