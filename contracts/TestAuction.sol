
//importing TestAuction contract and other relevant libraries.
let Auction = artifacts.require("./TestAuction.sol");
const truffleAssert = require("truffle-assertions");
const { time } = require("@openzeppelin/test-helpers");


//defining the tests within a contract block which provides access to etherium accounts.
contract("Auction", accounts => {
    //declare a variable to hold an instance of smart contract
    let testContract;
    //defining constant variables                               
    const PU_ACCOUNT = accounts[9];
    //definining constants for different states of the auction contract.
    const STATE_READY_FOR_BIDS = 0;
    const STATE_READY_FOR_BIDS_REVEAL = 1;
    const STATE_CLOSED= 2;
    const STATE_READY_FOR_DELETION = 3;

    const ONE_DAY = 86400;
    const BANDWIDTH = 200;
    const MIN_BID_VALUE = 50000;
    const MIN_USAGE_TIME = 1800;
    const DEPOSIT_VALUE = 100000;
    //defining an array for test bid values.
    const TEST_BIDS = [MIN_BID_VALUE , MIN_BID_VALUE + 1, MIN_BID_VALUE + 3, MIN_BID_VALUE + 4, MIN_BID_VALUE+2];
    //deploying the TestAuction contract before each test.
    beforeEach(async () => {
        //deploying an instance of the contract with specified parameters
        testContract = await Auction.new(
            PU_ACCOUNT,
            BANDWIDTH,
            MIN_BID_VALUE,
            DEPOSIT_VALUE,
            {
                gas: 4000000 //specify the gas limit for the deployment of the contract.
            }
        );
    });

    //defining a function to retrieve auction information from the test contract.
    //return the current state of the auction and its parameters
    getAuctionInfo= async () => {
        let info = await testContract.getAuctionInfo.call();
        return {
            "currentState": Number(info[0]),
            "PU": info[1],
            "bandwidth": Number(info[2]),
            "minBidValue": Number(info[3]),
            "depositValue": Number(info[4]),
            "BidsDeadline": Number(info[5]),
            "BidsRevealDeadline": Number(info[6]),
        };
    };


    //defining a function to place a bid in the first round.
    bidInBiddingRound = async (bidValue, bidTime, bidderAddress, depositValue) => {
    //calling the bidInBiddingRound while passing hashed bit value as the argument.
    let tx = await testContract.bidInBiddingRound(web3.utils.soliditySha3(bidValue,bidTime,"some_salt"),
     {
        value: depositValue,
        from: bidderAddress
    });
    //verifying that the ReceivedBid event is emiited correctly.
    truffleAssert.eventEmitted(tx, "ReceivedBid", (ev) => {
     return ev.SU == bidderAddress && ev.deposit == depositValue;
    });  
    };


    //defining a function to test revealing bids in the second round.
    bidInBidRevealRound = async (bidValue,bidTime, salt, bidderAddress) => {
    let tx = await testContract.bidInBidRevealRound(bidValue,bidTime, salt, { 
        from: bidderAddress
    });

    //verify that ReceivedBidReveal event is emitted with  correct parameters
    truffleAssert.eventEmitted(tx, "ReceivedBidReveal", (ev) => {
        return ev.SU == bidderAddress && ev.bid == bidValue && ev.UsageTime == bidTime;
    });
    };   

    it("contract is initialized with correct parameters and deadlines", async () => {

        let Auction_Info  = await getAuctionInfo();
        // get the latest time using the Time helper function
        const latestTime = await time.latest();
        //verifying that the current parameter values of the auction matches the expected parameter values
        expect(Auction_Info.currentState).to.equal(STATE_READY_FOR_BIDS);
        expect(Auction_Info.PU).to.equal(PU_ACCOUNT);
        expect(Auction_Info.bandwidth).to.equal(BANDWIDTH);
        expect(Auction_Info.minBidValue).to.equal(MIN_BID_VALUE);
        expect(Auction_Info.depositValue).to.equal(DEPOSIT_VALUE);
        expect(Auction_Info.BidsDeadline).to.equal(latestTime.toNumber() + ONE_DAY);
        expect(Auction_Info.BidsRevealDeadline).to.equal(latestTime.toNumber() + (ONE_DAY * 2));
    });

    

    /////test cases to check the functionalities of bidInBiddingRound() function of the auction smart contract.
     
    //test cases to check whether SUs can bid successfully in the first round
    it("can place bids successfully", async () => {
        //setting the current state to ready for bids state.
        await testContract.setCurrentState(STATE_READY_FOR_BIDS);
        //placing a bid in the bidding round
        await bidInBiddingRound(MIN_BID_VALUE,MIN_USAGE_TIME, accounts[1], DEPOSIT_VALUE);
        //retrieving the bid information
        const bid = await testContract.bids.call(accounts[1]);
        //checking whether the bid exits or not
        expect(bid.existsBid).to.equal(true);
       
    });

    it("stores bid information correctly when a bid is placed", async () => {
        //placing a bid in the bidding round
        await bidInBiddingRound(MIN_BID_VALUE, MIN_USAGE_TIME,accounts[1], DEPOSIT_VALUE);
        //retrieving the bid information
        const bid = await testContract.bids.call(accounts[1]);
        //verifying that the bid information is stored correctly.
        expect(bid.existsBid).to.equal(true);
        expect(bid.Bidding).to.equal(web3.utils.soliditySha3(MIN_BID_VALUE,MIN_USAGE_TIME,"some_salt"));
        expect(Number(bid.BidReveal)).to.equal(0);
        expect(Number(bid.minUsageTime)).to.equal(0);
        expect(bid.isBidRevealValid).to.equal(false);
        expect(Number(bid.deposit)).to.equal(DEPOSIT_VALUE);
             
    });

    it("adds SU's address to BidsAddresses array when a bid is placed", async () => {
        //placing a bid 
        await bidInBiddingRound(MIN_BID_VALUE,MIN_USAGE_TIME, accounts[1], DEPOSIT_VALUE);
        //retrieving the length of the bidsAdrreses array from the contract
        const bidsLength = await testContract.getBidsLength();
        //checking whether the bidders address is added to the array
        expect(Number(bidsLength)).to.equal(1);  
   });

   it("cannot place a bid when in an incorrect state",async() =>{
    //set the current state of the bid to STATE_CLOSED
        await testContract.setCurrentState(STATE_CLOSED);
    //checking whether the function reverts when palcing a bid with an incorrect state.
        await truffleAssert.reverts(
        bidInBiddingRound(MIN_BID_VALUE,MIN_USAGE_TIME, accounts[1], DEPOSIT_VALUE),
        "Invalid state "
    );

   });

   it("cannot place a bid in the bidding round after the deadline",async() =>{
    //increasing the time to be more than the bidding round deadline.
        await time.increase(ONE_DAY + 1);
    //checking whether the function reverts when palcing a bid after the deadline.
        await truffleAssert.reverts(
        bidInBiddingRound(MIN_BID_VALUE, MIN_USAGE_TIME,accounts[1], DEPOSIT_VALUE),
        "Cannot bid after deadline "
    );

   });


   it("cannot place a bid if the deposit amount is lower than the expected amount",async() =>{
   //checking whether the function reverts when palcing a bid with a low deposit amount that the minimum deposit value.
    await truffleAssert.reverts(
        bidInBiddingRound(MIN_BID_VALUE,MIN_USAGE_TIME,accounts[1],DEPOSIT_VALUE-1),
        "Deposit value is too low"
    ); 
   });


   

    /////test cases to verify the functionalities of closeBiddingRound() function of the auction smart contract.
    
    it("cannot close the bidding round before the deadline",async() =>{
        //set the time to be lower than the bidding round deadline. 
        await time.increase(ONE_DAY -1);
        //checking whether the function reverts when trying to close the bidding round before the deadline. 
        await truffleAssert.reverts(
            testContract.closeBiddingRound(),
            "Cannot perform this action before the deadline"
        )  
   });

   it("cannot close the bidding round if in an incorrect state",async() =>{
       //set the current state as STATE_READY_FOR_BIDS_REVEAL 
        await testContract.setCurrentState(STATE_READY_FOR_BIDS_REVEAL);
        //checking whether the function reverts when trying to close the bidding round while in an incorrect state.. 
        await truffleAssert.reverts(
            testContract.closeBiddingRound(),
            "Invalid state"
        )
   });

   it("auction should close if no hidden bids were recevied", async () => {
        //increaing the time beyond the bidding round deadline.
        await time.increase(ONE_DAY + 1);
        //set the current state of the test contract as STATE_READY_FOR_BIDS
        await testContract.setCurrentState(STATE_READY_FOR_BIDS);
        //set the number of bidders to 0.
        await testContract.clearBidsAddresses();
        //calling the closeBiddingRound() function 
        const tx = await testContract.closeBiddingRound();
        //check whether the state is changed to deletion state through closeBiddingRound() as no bids were received.
        const state = Number(await testContract.getCurrentState());
        expect(state).to.equal(STATE_READY_FOR_DELETION);
        //check whether the emitting event is ClosedAuctionWithNoBids 
        truffleAssert.eventEmitted(tx, "ClosedAuctionWithNoBids", (ev) => {
            return ev.whichRound == "Bidding round";
    });

    });

    it("auction should not be open for the bid revealing round if no hidden bids were recevied", async () => {
        //increaing the time beyond the bidding round deadline.
        await time.increase(ONE_DAY + 1);
        ////set the current state of the test contract as STATE_READY_FOR_BIDS
        await testContract.setCurrentState(STATE_READY_FOR_BIDS);
        //set the number of bidders to 0
        await testContract.clearBidsAddresses();
        const tx = await testContract.closeBiddingRound();
        //verify that ClosedRound event is not emitted when there are no received bids.
        await truffleAssert.eventNotEmitted(tx, "ClosedRound", (ev) => {
            return ev.whichRound == "Bidding round";     
        });
    });


   it("close bidding and open the bid revealing round when there are received bids",async() =>{
        //place a bid in the first round
        await bidInBiddingRound(MIN_BID_VALUE,MIN_USAGE_TIME, accounts[1], DEPOSIT_VALUE);
        //increaing the time beyond the bidding round deadline.
        await time.increase(ONE_DAY + 1);
        const tx = await testContract.closeBiddingRound();
        //verify whether ClosedRound event emit when calling closeBiddingRound() function.
        truffleAssert.eventEmitted(tx, "ClosedRound", (ev) => 
            ev.whichRound == "Bidding round");
        //verify that the currentstate of the test contract is changed correctly.
        const state = Number(await testContract.getCurrentState());
        expect(state).to.equal(STATE_READY_FOR_BIDS_REVEAL);

    });

    ////test cases to verify the functionalities of bidInBidRevealRound() function of the auction smart contract.
    it("can reveal bids and usage time in bid revealing round successfully", async () => {
        //place a bid in bidding round.
        await bidInBiddingRound(MIN_BID_VALUE, MIN_USAGE_TIME,accounts[1], DEPOSIT_VALUE);
        //increaing the time beyond the bidding round deadline.
        await time.increase(ONE_DAY + 1);
        await testContract.closeBiddingRound();
        //revealing bids in bid revealing round.
        await testContract.bidInBidRevealRound(MIN_BID_VALUE,MIN_USAGE_TIME, "some_salt", { from: accounts[1] });
        //retrieving the bid information
        let bid = await testContract.bids.call(accounts[1]);
        ////verifying that the bid information is changed correctly.
        expect(bid.existsBid).to.equal(true);
        expect(bid.isBidRevealValid).to.equal(true);
        expect(Number(bid.BidReveal)).to.equal(MIN_BID_VALUE);
        expect(Number(bid.minUsageTime)).to.equal(MIN_USAGE_TIME);

    });

   it("cannot bid in bid revealing round when in an incorrect state",async() =>{
        //place a bid in bidding round.
        await bidInBiddingRound(MIN_BID_VALUE,MIN_USAGE_TIME, accounts[1], DEPOSIT_VALUE);
        //increasing the time beyond the bidding round deadline
        await time.increase(ONE_DAY + 1);
        ////checking whether the function reverts when trying to reveal bids while in an incorrect state
        await truffleAssert.reverts(
            testContract.bidInBidRevealRound(MIN_BID_VALUE, MIN_USAGE_TIME,{ from: accounts[1] }),
            "Invalid state"
        );

    });
   it("cannot bid in bid revealing round after the bid revealing deadline",async() =>{
        //place a bid in bidding round.
        await bidInBiddingRound(MIN_BID_VALUE,MIN_USAGE_TIME, accounts[1], DEPOSIT_VALUE);
        await time.increase(ONE_DAY + 1);
        await testContract.closeBiddingRound();
        await time.increase(ONE_DAY);
        //checking whether the function reverts when trying to reveal bids after the bid revealing deadline
        await truffleAssert.reverts(
            testContract.bidInBidRevealRound(MIN_BID_VALUE,MIN_USAGE_TIME, { from: accounts[1] }),
            "Cannot bid after deadline"
        );
    });

   it("cannot reveal bids in bid revealing round if the bidder didnt bid in the bidding round",async() =>{ 
        await bidInBiddingRound(MIN_BID_VALUE, MIN_USAGE_TIME,accounts[1], DEPOSIT_VALUE);
        await time.increase(ONE_DAY + 1);
        await testContract.closeBiddingRound();
        ////checking whether the function reverts when a bidder who is not bid in the bidding round,is trying to reveal bids. 
        await truffleAssert.reverts(
            testContract.bidInBidRevealRound(MIN_BID_VALUE, MIN_USAGE_TIME,"some_salt", { from: accounts[4] }),
            "This account has not bid in the bidding round"
        );

   });

   it("cannot reveal bids in bid revealing round if bid is low", async () => {
        await bidInBiddingRound(MIN_BID_VALUE, MIN_USAGE_TIME,accounts[1], DEPOSIT_VALUE);
        await time.increase(ONE_DAY + 1);
        await testContract.closeBiddingRound();
        ////checking whether the function reverts when the bid value is too low.
        await truffleAssert.reverts(
            testContract.bidInBidRevealRound(MIN_BID_VALUE - 1,MIN_USAGE_TIME, "some_salt", { from: accounts[1] }),
            "Bid value is too low"
        );
    });

    it("cannot reveal bids in open round if reveal bid does not match the actual bid", async () => {
        await bidInBiddingRound(MIN_BID_VALUE,MIN_USAGE_TIME, accounts[1], DEPOSIT_VALUE);
        await time.increase(ONE_DAY + 1);
        await testContract.closeBiddingRound();
        ////checking whether the function reverts when the revealed bid values dont match with the hashed bid
        await truffleAssert.reverts(
            testContract.bidInBidRevealRound(MIN_BID_VALUE + 1,MIN_USAGE_TIME, "some_salt", { from: accounts[1] }),
            "Actual bid and revealing bid do not match"
        );
    });

    it("cannot reveal bids in open round if revealed minUsagetime does not match the actual minUsagetime ", async () => {
        await bidInBiddingRound(MIN_BID_VALUE,MIN_USAGE_TIME, accounts[1], DEPOSIT_VALUE);
        await time.increase(ONE_DAY + 1);
        await testContract.closeBiddingRound();
        ////checking whether the function reverts when the revealed bid values dont match with the hashed bid
        await truffleAssert.reverts(
            testContract.bidInBidRevealRound(MIN_BID_VALUE ,MIN_USAGE_TIME +4, "some_salt", { from: accounts[1] }),
            "Actual bid and revealing bid do not match"
        );
    });


});
