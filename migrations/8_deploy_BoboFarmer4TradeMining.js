const BoboFarmer4TradeMining = artifacts.require("BoboFarmer4TradeMining");
const BoboToken = artifacts.require("BoboToken");
const BoboFund = artifacts.require("BoboFund");
const OrderNFT = artifacts.require("OrderNFT");

module.exports = async function(deployer) {
  var boboToken = await BoboToken.deployed();

  // IBOBOToken _bobo,
  // IERC721 _nftToken,
  // address _fundContractAddr,
  var boboPerBlock = '1000000000000000000';
  var startBlock = 0;
  var endBlock = 18993739 + 30 * 24 * 3600 / 2;
  var nftStartTime = 0;
  var nftEndTime = new Date(2021, 9, 30).getTime() / 1000;
  
  await deployer.deploy(BoboFarmer4TradeMining, BoboToken.address, OrderNFT.address, BoboFund.address, boboPerBlock, startBlock, endBlock, nftStartTime, nftEndTime);
  var boboFarmer4TradeMining = await BoboFarmer4TradeMining.deployed();
  await boboToken.addMinter(boboFarmer4TradeMining.address);
  
  await boboFarmer4TradeMining.setFundScale(2, 3);
};