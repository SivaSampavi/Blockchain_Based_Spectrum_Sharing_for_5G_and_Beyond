let AdvertisementController = artifacts.require("./AdvertisementController.sol");

module.exports = async (deployer) => {
    await deployer.deploy(AdvertisementController);
}