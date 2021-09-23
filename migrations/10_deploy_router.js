const BoboRouter = artifacts.require("BoboRouter");
const BoboRouterOnNear = artifacts.require("BoboRouterOnNear");

module.exports = async function(deployer, network) {
  if (network == 'matic') {
    await deployer.deploy(BoboRouter);
  } else if (network == 'aurora') {
    await deployer.deploy(BoboRouterOnNear);
  }
};
