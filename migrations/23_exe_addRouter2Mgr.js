const BoboRouter = artifacts.require("BoboRouter");
const EXManager = artifacts.require("EXManager");

// EXManager address: 0x84BdD98aac8fAc344F8605fc60c5c8676264D7eF
module.exports = async function(deployer) {
    var exManager = await EXManager.deployed();
    exManager.setRouter(BoboRouter.address, true);
};
