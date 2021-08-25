const BatchCreatePairs = artifacts.require("BatchCreatePairs");

module.exports = async function(deployer) {
  var batchCreatePairs = await BatchCreatePairs.deployed();

  await batchCreatePairs.creatUSDTPeers(0, 1);
  await batchCreatePairs.creatUSDCPeers(0, 1);
};
