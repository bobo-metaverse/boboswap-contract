const BatchCreatePairs = artifacts.require("BatchCreatePairs");
const OrderNFT = artifacts.require("OrderNFT");
const OrderDetailNFT = artifacts.require("OrderDetailNFT");
const BoboFarmer = artifacts.require("BoboFarmer");
const EXManager = artifacts.require("EXManager");
const BoboFactoryOnMatic = artifacts.require("BoboFactoryOnMatic");
const BoboPair = artifacts.require("BoboPair");

const USDT = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F";
const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
    
    
// const USDT_PEERS = [
//                   0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
//                   0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
//                   0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6, 
//                   0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, 
//                   0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, 
//                   0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39, 
//                   0x9c2C5fd7b07E95EE044DDeba0E97a665F142394f, 
//                   0xb33EaAd8d922B1083446DC23f610c2567fB5180f,
//                   0xD6DF932A45C0f255f85145f286eA0b292B21C90B
//                 ];
    
// const USDC_PEERS = [
//                   0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
//                   0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
//                   0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6, 
//                   0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, 
//                   0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39, 
//                   0x9c2C5fd7b07E95EE044DDeba0E97a665F142394f, 
//                   0xb33EaAd8d922B1083446DC23f610c2567fB5180f,
//                   0xD6DF932A45C0f255f85145f286eA0b292B21C90B 
//                 ];
        

module.exports = async function(deployer) {
  var boboFactory = await BoboFactoryOnMatic.deployed();
  var orderNFT = await OrderNFT.deployed();
  var orderDetailNFT = await OrderDetailNFT.deployed();
  var boboFarmer = await BoboFarmer.deployed();
  var exManager = await EXManager.deployed();


  await boboFactory.createPair(WMATIC, USDT);
  var pairAddr = await boboFactory.getPair(WMATIC, USDT);

  await orderNFT.addMinter(pairAddr);
  await orderDetailNFT.addMinter(pairAddr);
  await boboFarmer.addAuthorized(pairAddr);
  await exManager.addAuthorized(pairAddr);
};
