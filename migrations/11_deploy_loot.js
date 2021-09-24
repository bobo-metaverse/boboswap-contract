const Loot = artifacts.require("Loot");
const OrderNFT = artifacts.require("OrderNFT");

module.exports = async function(deployer, network) {
  if (network == 'matic') {
    await deployer.deploy(Loot, "2000000000000000000", OrderNFT.address);  // 2 matic
  } else if (network == 'arbitrum') {
    await deployer.deploy(Loot, "1000000000000000", OrderNFT.address);  // 0.001 ETH
  } else if (network == 'avax') {
    await deployer.deploy(Loot, "50000000000000000", OrderNFT.address);  //  0.05 AVAX
  }
};
