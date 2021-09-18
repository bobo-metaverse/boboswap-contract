const BoboRouter = artifacts.require("BoboRouter");

module.exports = async function(deployer) {
  const boboRouter = await BoboRouter.deployed();
  boboRouter.setFeeRate(5000);  // 5000 / 10000 = 50%
};
