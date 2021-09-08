const NewStratMaticSushi = artifacts.require("NewStratMaticSushi");
const BoboFarmer = artifacts.require("BoboFarmer");

module.exports = async function(deployer) {

  var boboFarmer = await BoboFarmer.deployed();
  var poolInfo = await boboFarmer.poolInfo(0);
  console.log(poolInfo.strat);
  var stratMaticSushi = await NewStratMaticSushi.at(poolInfo.strat);
  await stratMaticSushi.earn();
};
