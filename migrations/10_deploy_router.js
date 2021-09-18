const BoboRouter = artifacts.require("BoboRouter");

module.exports = async function(deployer) {
  await deployer.deploy(BoboRouter);
};
