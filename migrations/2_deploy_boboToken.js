
const BoboToken = artifacts.require("BoboToken");

module.exports = async function(deployer, network) {
  console.log(network);
  await deployer.deploy(BoboToken);
};
