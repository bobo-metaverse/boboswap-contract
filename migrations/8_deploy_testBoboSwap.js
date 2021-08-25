const BoboSwapTester = artifacts.require("BoboSwapTester");
const OrderNFT = artifacts.require("OrderNFT");
const BoboFarmer = artifacts.require("BoboFarmer");
const BoboFactoryOnMatic = artifacts.require("BoboFactoryOnMatic");
const StratMaticSushi = artifacts.require("StratMaticSushi");

module.exports = async function(deployer) {
  await deployer.deploy(BoboSwapTester, BoboFactoryOnMatic.address, BoboFarmer.address, StratMaticSushi.address, OrderNFT.address);
};