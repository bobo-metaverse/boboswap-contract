
const BoboToken = artifacts.require("BoboToken");
const BoboBetaToken = artifacts.require("BOBOBetaToken");

const BoboFarmer = artifacts.require("BoboFarmer");
const StratMaticSushi = artifacts.require("StratMaticSushi");

module.exports = async function(deployer, network, accounts) {
  var boboBetaToken = await BoboBetaToken.deployed();
  var boboToken = await BoboToken.deployed();

  await deployer.deploy(BoboFarmer, boboBetaToken.address, 17609065, accounts[0]);
  var boboFarmer = await BoboFarmer.deployed();
  boboFarmer.setBoboPerBlock(10);

  boboBetaToken.addMinter(boboFarmer.address);
  boboToken.addMinter(boboFarmer.address);

  await deployer.deploy(StratMaticSushi, boboBetaToken.address, boboFarmer.address);
  var stratMaticSushi = await StratMaticSushi.deployed();

  var USDT = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
  var USDC = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
  boboFarmer.add(10, USDT, false, stratMaticSushi.address);
  boboFarmer.add(10, USDC, false, stratMaticSushi.address);
};
