const BoboFarmer = artifacts.require("BoboFarmer");
const NewStratMaticSushi = artifacts.require("NewStratMaticSushi");

module.exports = async function(deployer, network, accounts) {
  var boboFarmer = await BoboFarmer.deployed();

  var newStratMaticSushi = await NewStratMaticSushi.deployed();
  console.log("newStratMaticSushi address:", newStratMaticSushi.address);

  var USDT = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
  var USDC = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
  console.log("start migrate USDT strat");
  await boboFarmer.migrateNewStrat(USDT, newStratMaticSushi.address);
  console.log("start migrate USDC strat");
  await boboFarmer.migrateNewStrat(USDC, newStratMaticSushi.address);


  // console.log("get back USDT");
  // await newStratMaticSushi.getBackToken(USDT);
  // console.log("get back USDc");
  // await newStratMaticSushi.getBackToken(USDC);
};
