const BoboRouter = artifacts.require("BoboRouter");
const EXManager = artifacts.require("EXManager");
const OrderNFT = artifacts.require("OrderNFT");
const OrderDetailNFT = artifacts.require("OrderDetailNFT");
const BoboFarmer = artifacts.require("BoboFarmer");
const BoboFactoryOnMatic = artifacts.require("BoboFactoryOnMatic");
const BatchCreatPairs = artifacts.require("BatchCreatPairs");

module.exports = async function(deployer) {
  var boboRouter = await BoboRouter.deployed();
  var exManager = await EXManager.deployed();
  var orderNFT = await OrderNFT.deployed();
  var orderDetailNFT = await OrderDetailNFT.deployed();
  var boboFarmer = await BoboFarmer.deployed();
  var boboFactory = await BoboFactoryOnMatic.deployed();
  var batchCreatePairs = await BatchCreatPairs.deployed();

  var exManagerOwner = await exManager.owner();
  if (BatchCreatPairs.address != exManagerOwner) {
    console.log('exManagerOwner', exManagerOwner, BatchCreatPairs.address);
  }
  var orderNFTOwner = await orderNFT.owner();
  if (BatchCreatPairs.address != orderNFTOwner) {
    console.log('orderNFTOwner', orderNFTOwner, BatchCreatPairs.address);
  }
  var orderDetailNFTOwner = await orderDetailNFT.owner();
  if (BatchCreatPairs.address != orderDetailNFTOwner) {
    console.log('orderDetailNFTOwner', orderDetailNFTOwner, BatchCreatPairs.address);
  }
  var boboFarmerOwner = await boboFarmer.owner(); 
  if (BatchCreatPairs.address != boboFarmerOwner) {
    console.log('boboFarmerOwner', boboFarmerOwner, BatchCreatPairs.address);
  }
  var boboFactoryOwner = await boboFactory.owner(); 
  if (BatchCreatPairs.address != boboFactoryOwner) {
    console.log('boboFactoryOwner', boboFactoryOwner, BatchCreatPairs.address);
    await boboFactory.transferOwnership(BatchCreatPairs.address);
  } 

  console.log(boboRouter.address, boboFactory.address, boboFarmer.address, exManager.address, orderNFT.address, orderDetailNFT.address, batchCreatePairs.address);
//   var batchCreatePairs = await BatchCreatPairs.at('0xF3E551A714b4134C51A8703213d3BCa05fd133b8');
//  await batchCreatePairs.setAddrs(boboRouter.address, boboFactory.address, boboFarmer.address, exManager.address, orderNFT.address, orderDetailNFT.address);
  
//   await exManager.transferOwnership(batchCreatePairs.address);
//   await orderNFT.transferOwnership(batchCreatePairs.address);
//   await orderDetailNFT.transferOwnership(batchCreatePairs.address);
//   await boboFarmer.transferOwnership(batchCreatePairs.address);
//   await boboFactory.transferOwnership(batchCreatePairs.address);
//     await batchCreatePairs.creatUSDTPeers(1, 3);
    //  await batchCreatePairs.creatUSDTPeers(3, 6);
    //  await batchCreatePairs.creatUSDTPeers(6, 9);
  
    //  await batchCreatePairs.creatUSDCPeers(0, 3);
    //  await batchCreatePairs.creatUSDCPeers(3, 6);
    //  await batchCreatePairs.creatUSDCPeers(6, 8);

    // var batchCreatePairs = await BatchCreatPairs.at('0xF3E551A714b4134C51A8703213d3BCa05fd133b8');
    batchCreatePairs.transferAllOwner('0x803827AAd684984fFB55A90C33CbCaee6f62C407');
};
