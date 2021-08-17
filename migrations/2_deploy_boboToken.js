
const BoboToken = artifacts.require("BoboToken");
//const BoboBetaToken = artifacts.require("BoboBetaToken");

module.exports = async function(deployer) {
  await deployer.deploy(BoboToken);
  //await deployer.deploy(BoboBetaToken);
};
