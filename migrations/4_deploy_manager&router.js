const BoboRouter = artifacts.require("BoboRouter");
const EXManager = artifacts.require("EXManager");
const BoboToken = artifacts.require("BoboToken");

// EXManager address: 0x84BdD98aac8fAc344F8605fc60c5c8676264D7eF
module.exports = async function(deployer) {
  await deployer.deploy(BoboRouter);

  var boboToken = await BoboToken.deployed();
  await deployer.deploy(EXManager, boboToken.address);
};
