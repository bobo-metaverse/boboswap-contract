const BoboFarmer = artifacts.require("BoboFarmer");
const BoboFactory = artifacts.require("BoboFactory");
const EXManager = artifacts.require("EXManager");
const OrderNFT = artifacts.require("OrderNFT");
const OrderDetailNFT = artifacts.require("OrderDetailNFT");
const BoboRouter = artifacts.require("BoboRouter");
//const BatchCreatePairs = artifacts.require("BatchCreatePairs");

// async function createFactory(deployer) {
//     await deployer.deploy(BoboFactoryOnMatic, OrderNFT.address, OrderDetailNFT.address, BoboFarmer.address);
//     var boboFactory = await BoboFactoryOnMatic.deployed();
//     //boboFactory.transferOwnership(BatchCreatPairs.address);
    
//     var boboFarmer = await BoboFarmer.deployed();
//     boboFarmer.addAuthorized(boboFactory.address);
// }

// async function getPair(deployer, factoryAddr, tokenA, tokenB) {
//     var boboFactory = await BoboFactoryOnMatic.at(factoryAddr);
//     var pairAddr = await boboFactory.getPair(tokenA, tokenB);
//     console.log(pairAddr);
//     return pairAddr;
// }

// async function addOrders(pairAddr, account) {
//     const boboPair = await BoboPair.at(pairAddr);
//     const usdt = await ERC20.at('0xc2132D05D31c914a87C6611C10748AEb04B58e8F');
//     const matic = await ERC20.at('0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270');
//     if (usdt.allowance(account, boboPair.address) < 100000000) {
//         await usdt.approve(boboPair, 100000000000);
//     }
//     if (matic.allowance(account, boboPair.address) < 100000000) {
//         await matic.approve(boboPair, 100000000000);
//     }
//     console.log("addLimitedOrder: buy matic");
//     await boboPair.addLimitedOrder(true, 990000, 100000, 100);
//     await boboPair.addLimitedOrder(true, 980000, 100000, 100);
//     await boboPair.addLimitedOrder(true, 970000, 100000, 100);
//     await boboPair.addLimitedOrder(true, 970000, 100000, 100);
//     await boboPair.addLimitedOrder(true, 960000, 100000, 100);
//     await boboPair.addLimitedOrder(true, 950000, 100000, 100);

//     console.log("addLimitedOrder: sell matic");
//     await boboPair.addLimitedOrder(false, 1200000, '0x16345785d8a0000', 100);
//     await boboPair.addLimitedOrder(false, 1300000, '0x16345785d8a0000', 100);
//     await boboPair.addLimitedOrder(false, 1400000, '0x16345785d8a0000', 100);
//     await boboPair.addLimitedOrder(false, 1500000, '0x16345785d8a0000', 100);
//     await boboPair.addLimitedOrder(false, 1600000, '0x16345785d8a0000', 100);
//     await boboPair.addLimitedOrder(false, 1600000, '0x16345785d8a0000', 100);
// }

// async function cancelOrder(pairAddr, account) {
//     const boboPair = await BoboPair.at(pairAddr);
//     const number = await boboPair.getUserHangingOrderNumber(account);
//     console.log(number.toNumber());
//     for (var i = 0; i < 1 && i < number; i++) {
//         const id = await boboPair.getUserHangingOrderId(account, i);
//         console.log(id);
//         await boboPair.cancelOrder(id);
//     }
// }

module.exports = async function(deployer, network, accounts) {
    console.log(OrderNFT.address, BoboFarmer.address, EXManager.address, BoboRouter.address);
    await deployer.deploy(BoboFactory, OrderNFT.address, BoboFarmer.address, EXManager.address);
    var boboFactory = await BoboFactory.deployed();
    
    var boboFarmer = await BoboFarmer.deployed();
    boboFarmer.addAuthorized(boboFactory.address);
};
