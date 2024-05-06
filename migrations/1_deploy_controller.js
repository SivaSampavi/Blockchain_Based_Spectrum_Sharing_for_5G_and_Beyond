let AuctionController = artifacts.require("./AuctionController.sol");

module.exports = async (deployer) => {
    await deployer.deploy(AuctionController);
}