const BoboSwapTester = artifacts.require("BoboSwapTester");
const OrderNFT = artifacts.require("OrderNFT");
const BoboFarmer = artifacts.require("BoboFarmer");
const BoboFactory = artifacts.require("BoboFactory");
const StratMaticSushi = artifacts.require("StratMaticSushi");

module.exports = async function(deployer) {
  await deployer.deploy(BoboSwapTester, BoboFactory.address, BoboFarmer.address, StratMaticSushi.address, OrderNFT.address);
};