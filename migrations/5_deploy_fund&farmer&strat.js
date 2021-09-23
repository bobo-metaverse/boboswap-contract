
const BoboToken = artifacts.require("BoboToken");
const BoboFund = artifacts.require("BoboFund");
const BoboFarmer = artifacts.require("BoboFarmer");
const StratMaticSushi = artifacts.require("StratMaticSushi");
const StratOnAurora = artifacts.require("StratOnAurora");

module.exports = async function(deployer, network, accounts) {
  var boboToken = await BoboToken.deployed();

  await deployer.deploy(BoboFund, BoboToken.address);
  var boboFund = await BoboFund.deployed();

  await deployer.deploy(BoboFarmer, boboToken.address, boboFund.address);
  var boboFarmer = await BoboFarmer.deployed();

  boboToken.addMinter(boboFarmer.address);

  var strat;

  if (network == 'matic') {
    await deployer.deploy(StratMaticSushi, boboToken.address, boboFarmer.address);
    strat = await StratMaticSushi.deployed();
  } else if (network == 'aurora') {
    await deployer.deploy(StratOnAurora, boboToken.address, boboFarmer.address);
    strat = await StratOnAurora.deployed();
  }

  var USDT = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
  var USDC = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
  boboFarmer.add(10, USDT, false, strat.address);
  boboFarmer.add(10, USDC, false, strat.address);
};
