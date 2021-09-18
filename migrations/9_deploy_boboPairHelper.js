const BoboPairHelper = artifacts.require("BoboPairHelper");

module.exports = async function(deployer) {
  await deployer.deploy(BoboPairHelper);
};
