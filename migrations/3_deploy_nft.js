
const OrderNFT = artifacts.require("OrderNFT");
const OrderDetailNFT = artifacts.require("OrderDetailNFT");

module.exports = async function(deployer) {
  await deployer.deploy(OrderNFT);
  await deployer.deploy(OrderDetailNFT);

  var orderNFT = await OrderNFT.deployed();
  var orderDetailNFT = await OrderDetailNFT.deployed();

  orderNFT.setOrderDetailNFTContract(orderDetailNFT.address);
  orderDetailNFT.setOrderNFT(orderNFT.address);
};
