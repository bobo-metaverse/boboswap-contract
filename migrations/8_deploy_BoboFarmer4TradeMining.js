const BoboFarmer4TradeMining = artifacts.require("BoboFarmer4TradeMining");
const BoboToken = artifacts.require("BoboToken");
const BoboFund = artifacts.require("BoboFund");
const OrderNFT = artifacts.require("OrderNFT");

module.exports = async function(deployer) {
  //var boboToken = await BoboToken.deployed();

  // IBOBOToken _bobo,
  // IERC721 _nftToken,
  // address _fundContractAddr,
  var boboPerBlock = 0;
  var startBlock = 0;
  var endBlock = 0;
  var nftStartTime = 0;
  var nftEndTime = 0;
  
  await deployer.deploy(BoboFarmer4TradeMining, BoboToken.address, OrderNFT.address, BoboFund.address, boboPerBlock, startBlock, endBlock, nftStartTime, nftEndTime);
};