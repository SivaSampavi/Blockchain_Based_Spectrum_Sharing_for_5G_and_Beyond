let AuctionController = artifacts.require("./TestAuctionController.sol");
let Auction = artifacts.require("./TestAuction.sol");
const truffleAssert = require("truffle-assertions");
const { time } = require("@openzeppelin/test-helpers");

contract("AuctionController", accounts => {
    let contract;
    const owner = accounts[0];
    const PU = accounts[1];
    const bandwidth = 200;
    const minBid = 5000000;
    const deposit = 1000000000;
    const ONE_DAY = 86400;
    const minUsageTime=100;

    beforeEach(async () => {
        contract = await AuctionController.new(
            { from: owner, gas: 6700000 }
        );
    });

    it("contract is initialized", async () => {
        const admin = await contract.testGetAdmin();
        expect(admin).to.equal(owner);
    });

     it("can deploy new auction contract", async () => {
        const tx = await contract.deployNewAuction(
            PU, 
            bandwidth, 
            minBid, 
            deposit,
        );

        const newAuctionAddress = tx.logs[0].args.auction;
        const PUAddress = await contract.PUAddresses.call(newAuctionAddress);
        expect(PUAddress).to.equal(PU);
        
        const auction = await Auction.at(newAuctionAddress);
        const {1: aPU, 2: aBandwidth, 3: aMinBid, 4: aDeposit} = await auction.getAuctionInfo();
        expect(aPU).to.equal(PU);
        expect(Number(aBandwidth)).to.equal(bandwidth);
        expect(Number(aMinBid)).to.equal(minBid);
        expect(Number(aDeposit)).to.equal(deposit);

        truffleAssert.eventEmitted(tx, "AddedNewAuction");
    });

    it("cannot delete auction if not admin or auction PU", async () => {
        const tx = await contract.deployNewAuction(
            PU, 
            bandwidth, 
            minBid, 
            deposit,
        );

        const newAuctionAddress = tx.logs[0].args.auction;

        await truffleAssert.reverts(
            contract.deleteAuction(newAuctionAddress, { from: accounts[2] }),
            "Can only be deleted by admin or the auction PU"
        );
    });

    it("cannot delete auction if in the Bidding round", async () => {
        const tx = await contract.deployNewAuction(
            PU, 
            bandwidth, 
            minBid, 
            deposit,
        );
        
        const newAuctionAddress = tx.logs[0].args.auction;
        
        await truffleAssert.reverts(
            contract.deleteAuction(newAuctionAddress, { from: owner }),
            "Cannot delete auction before the token has expired or been retrieved"
        );
    });

    it("cannot delete auction if in the bid revealing round", async () => {
        const tx = await contract.deployNewAuction(
            PU, 
            bandwidth, 
            minBid, 
            deposit,
        );
        
        const newAuctionAddress = tx.logs[0].args.auction;
        const auction = await Auction.at(newAuctionAddress);
        await auction.bidInBiddingRound(web3.utils.soliditySha3(minBid, "some salt"), { from: accounts[2], value: deposit });
        await time.increase(ONE_DAY + 1);
        await auction.closeBiddingRound();
        
        await truffleAssert.reverts(
            contract.deleteAuction(newAuctionAddress, { from: owner }),
            "Cannot delete auction before the token has expired or been retrieved"
        );
    });

    it("cannot delete auction if the token has not yet expired or been retrieved", async () => {
        const minUsageTime = 100; 
        const tx = await contract.deployNewAuction(
            PU, 
            bandwidth, 
            minBid, 
            deposit,
        );
        
        const newAuctionAddress = tx.logs[0].args.auction;
        const auction = await Auction.at(newAuctionAddress);
        //const salt = web3.utils.randomHex(32); // Generate a random 32-byte hexadecimal string (salt)
        await auction.bidInBiddingRound(web3.utils.soliditySha3(minBid,minUsageTime,"some salt"), { from: accounts[2], value: deposit });
        await time.increase(ONE_DAY + 1);
        await auction.closeBiddingRound();

        await auction.bidInBidRevealRound(minBid,minUsageTime, "some salt", { from: accounts[2] });
        await time.increase(ONE_DAY + 1);
        await auction.closeAuction();
        
        await truffleAssert.reverts(
            contract.deleteAuction(newAuctionAddress, { from: owner }),
            "Cannot delete auction before the token has expired or been retrieved"
        );
    });

    it("admin can delete auction", async () => {
        const auctionAddress = await mockAuction(PU);
        const deleteTx = await contract.deleteAuction(auctionAddress, { from: owner });
        truffleAssert.eventEmitted(deleteTx, "DeletedAuction", (ev) => ev.auction == auctionAddress);
    });

    it("PU can delete auction", async () => {
        const auctionAddress = await mockAuction(PU);

        const deleteTx = await contract.deleteAuction(auctionAddress, { from: PU });
        truffleAssert.eventEmitted(deleteTx, "DeletedAuction", (ev) => ev.auction == auctionAddress);
    });

    it("PU can delete his own auction, but not one from another PU", async () => {
        const PUsAuction = await mockAuction(PU);
        const anotherAuction = await mockAuction(accounts[2]);
        
        const deleteTx = await contract.deleteAuction(PUsAuction, { from: PU });
        truffleAssert.eventEmitted(deleteTx, "DeletedAuction", (ev) => ev.auction == PUsAuction);

        await truffleAssert.reverts(
            contract.deleteAuction(anotherAuction, { from: PU }),
            "Can only be deleted by admin or the auction PU"
        );
    });

    mockAuction = async (PUAddress) => {
        const tx = await contract.deployNewAuction(
            PUAddress, 
            bandwidth, 
            minBid, 
            deposit,
        );
        
        const newAuctionAddress = tx.logs[0].args.auction;
        const auction = await Auction.at(newAuctionAddress);
        
        await auction.bidInBiddingRound(web3.utils.soliditySha3(minBid,minUsageTime, "some_salt"), { from: accounts[2], value: deposit });
        await time.increase(ONE_DAY + 1);
        await auction.closeBiddingRound();
        await auction.bidInBidRevealRound(minBid, minUsageTime, "some_salt", { from: accounts[2] });
        await time.increase(ONE_DAY + 1);
        await auction.closeAuction();
        await auction.retrieveToken({ from: accounts[2] });

        return newAuctionAddress;
    };
  });