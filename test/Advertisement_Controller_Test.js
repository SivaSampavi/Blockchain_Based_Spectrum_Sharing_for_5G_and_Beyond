let AdvertisementController = artifacts.require("./TestAdvertisementController.sol");
let Advertisement = artifacts.require("./TestAdvertisement.sol");
const truffleAssert = require("truffle-assertions");
const { time } = require("@openzeppelin/test-helpers");

contract("AdvertisementController", accounts => {
    let contract;
    const owner = accounts[0];
    const PU = accounts[1];
    const bandwidth = 200;
    const minBid = 5000000;
    const deposit = 1000000000;
    const ONE_DAY = 86400;
    const minUsageTime=100;

    beforeEach(async () => {
        contract = await AdvertisementController.new(
            { from: owner, gas: 6700000 }
        );
    });

    it("contract is initialized", async () => {
        const admin = await contract.testGetAdmin();
        expect(admin).to.equal(owner);
    });

     it("can deploy new advertisement contract", async () => {
        const tx = await contract.deployNewAdvertisement(
            PU, 
            bandwidth, 
            minBid, 
            deposit,
        );

        const newAdvertisementAddress = tx.logs[0].args.advertisement;
        const PUAddress = await contract.PUAddresses.call(newAdvertisementAddress);
        expect(PUAddress).to.equal(PU);
        
        const advertisement = await Advertisement.at(newAdvertisementAddress);
        const {1: aPU, 2: aBandwidth, 3: aMinBid, 4: aDeposit} = await advertisement.getAdvertisementInfo();
        expect(aPU).to.equal(PU);
        expect(Number(aBandwidth)).to.equal(bandwidth);
        expect(Number(aMinBid)).to.equal(minBid);
        expect(Number(aDeposit)).to.equal(deposit);

        truffleAssert.eventEmitted(tx, "AddedNewAdvertisement");
    });

    it("cannot delete advertisement if not admin or advertisement PU", async () => {
        const tx = await contract.deployNewAdvertisement(
            PU, 
            bandwidth, 
            minBid, 
            deposit,
        );

        const newAdvertisementAddress = tx.logs[0].args.advertisement;

        await truffleAssert.reverts(
            contract.deleteAdvertisement(newAdvertisementAddress, { from: accounts[2] }),
            "Can only be deleted by admin or the advertisement PU"
        );
    });

    it("cannot delete advertisement if in the Bidding round", async () => {
        const tx = await contract.deployNewAdvertisement(
            PU, 
            bandwidth, 
            minBid, 
            deposit,
        );
        
        const newAdvertisementAddress = tx.logs[0].args.advertisement;
        
        await truffleAssert.reverts(
            contract.deleteAdvertisement(newAdvertisementAddress, { from: owner }),
            "Cannot delete advertisement before the token has expired or been retrieved"
        );
    });

    it("cannot delete advertisement if in the bid revealing round", async () => {
        const tx = await contract.deployNewAdvertisement(
            PU, 
            bandwidth, 
            minBid, 
            deposit,
        );
        
        const newAdvertisementAddress = tx.logs[0].args.advertisement;
        const advertisement = await Advertisement.at(newAdvertisementAddress);
        await advertisement.bidInBiddingRound(web3.utils.soliditySha3(minBid,minUsageTime, "some salt"), { from: accounts[2], value: deposit });
        await time.increase(ONE_DAY + 1);
        await advertisement.closeBiddingRound();
        
        await truffleAssert.reverts(
            contract.deleteAdvertisement(newAdvertisementAddress, { from: owner }),
            "Cannot delete advertisement before the token has expired or been retrieved"
        );
    });

    it("cannot delete advertisement if the token has not yet expired or been retrieved", async () => {
        const tx = await contract.deployNewAdvertisement(
            PU, 
            bandwidth, 
            minBid, 
            deposit,
        );
        
        const newAdvertisementAddress = tx.logs[0].args.advertisement;
        const advertisement = await Advertisement.at(newAdvertisementAddress);
        //const salt = web3.utils.randomHex(32); // Generate a random 32-byte hexadecimal string (salt)
        await advertisement.bidInBiddingRound(web3.utils.soliditySha3(minBid,minUsageTime,"some salt"), { from: accounts[2], value: deposit });
        await time.increase(ONE_DAY + 1);
        await advertisement.closeBiddingRound();

        await advertisement.bidInBidRevealRound(minBid,minUsageTime, "some salt", { from: accounts[2] });
        await time.increase(ONE_DAY + 1);
        await advertisement.closeAdvertisement();
        
        await truffleAssert.reverts(
            contract.deleteAdvertisement(newAdvertisementAddress, { from: owner }),
            "Cannot delete advertisement before the token has expired or been retrieved"
        );
    });

    it("admin can delete advertisement", async () => {
        const advertisementAddress = await mockAdvertisement(PU);
        const deleteTx = await contract.deleteAdvertisement(advertisementAddress, { from: owner });
        truffleAssert.eventEmitted(deleteTx, "DeletedAdvertisement", (ev) => ev.advertisement == advertisementAddress);
    });

    it("PU can delete advertisement", async () => {
        const advertisementAddress = await mockAdvertisement(PU);

        const deleteTx = await contract.deleteAdvertisement(advertisementAddress, { from: PU });
        truffleAssert.eventEmitted(deleteTx, "DeletedAdvertisement", (ev) => ev.advertisement == advertisementAddress);
    });

    it("PU can delete his own advertisement, but not one from another PU", async () => {
        const PUsAdvertisement = await mockAdvertisement(PU);
        const anotherAdvertisement = await mockAdvertisement(accounts[2]);
        
        const deleteTx = await contract.deleteAdvertisement(PUsAdvertisement, { from: PU });
        truffleAssert.eventEmitted(deleteTx, "DeletedAdvertisement", (ev) => ev.advertisement == PUsAdvertisement);

        await truffleAssert.reverts(
            contract.deleteAdvertisement(anotherAdvertisement, { from: PU }),
            "Can only be deleted by admin or the advertisement PU"
        );
    });

    mockAdvertisement = async (PUAddress) => {
        const tx = await contract.deployNewAdvertisement(
            PUAddress, 
            bandwidth, 
            minBid, 
            deposit,
        );
        
        const newAdvertisementAddress = tx.logs[0].args.advertisement;
        const advertisement = await Advertisement.at(newAdvertisementAddress);
        
        await advertisement.bidInBiddingRound(web3.utils.soliditySha3(minBid,minUsageTime, "some_salt"), { from: accounts[2], value: deposit });
        await time.increase(ONE_DAY + 1);
        await advertisement.closeBiddingRound();
        await advertisement.bidInBidRevealRound(minBid, minUsageTime, "some_salt", { from: accounts[2] });
        await time.increase(ONE_DAY + 1);
        await advertisement.closeAdvertisement();
        await advertisement.retrieveToken({ from: accounts[2] });

        return newAdvertisementAddress;
    };
  });