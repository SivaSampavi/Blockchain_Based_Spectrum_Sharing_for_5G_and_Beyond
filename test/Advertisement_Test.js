//importing TestAdvertisement contract and other relevant libraries.
let Advertisement = artifacts.require("./TestAdvertisement.sol");
const truffleAssert = require("truffle-assertions");
const { time } = require("@openzeppelin/test-helpers");


//defining the tests within a contract block which provides access to etherium accounts.
contract("Advertisement", accounts => {
    //declare a variable to hold an instance of smart contract
    let testContract;
    //defining constant variables                               
    const PU_ACCOUNT = accounts[9];
    //definining constants for different states of the advertisement contract.
    const STATE_READY_FOR_BIDS = 0;
    const STATE_READY_FOR_BIDS_REVEAL = 1;
    const STATE_CLOSED= 2;
    const STATE_READY_FOR_DELETION = 3;

    const ONE_DAY = 86400;
    const BANDWIDTH = 200;
    const MIN_BID_VALUE = 5000;
    const MIN_USAGE_TIME = 180;
    const DEPOSIT_VALUE = 1000000;
    //defining two arrays for test bid values and test minimum usage values .
    const TEST_BIDS = [MIN_BID_VALUE +1  , MIN_BID_VALUE + 1, MIN_BID_VALUE + 3, MIN_BID_VALUE + 4, MIN_BID_VALUE+2];
    const TEST_MIN_USAGE_TIME = [MIN_USAGE_TIME , MIN_USAGE_TIME + 5, MIN_USAGE_TIME + 10, MIN_USAGE_TIME - 60, MIN_USAGE_TIME - 10];

    //deploying the TestAdvertisement contract before each test.
    beforeEach(async () => {
        //deploying an instance of the contract with specified parameters
        testContract = await Advertisement.new(
            PU_ACCOUNT,
            BANDWIDTH,
            MIN_BID_VALUE,
            DEPOSIT_VALUE,
            {
                gas: 5000000 //specify the gas limit for the deployment of the contract.
            }
        );
    });

    //defining a function to retrieve advertisement information from the test contract.
    //return the current state of the advertisement and its parameters
    getAdvertisementInfo= async () => {
        let info = await testContract.getAdvertisementInfo.call();
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
     // Function to simulate the bidding process
    TestBidding = async (bids, minUsageTime, includeInvalidBid = false) => {                           
        for (let i = 0; i < bids.length; i++) {                                                         // Loop through each bid
            await bidInBiddingRound(bids[i], minUsageTime[i], accounts[i + 1], DEPOSIT_VALUE);          // Place a bid in the bidding round for each bidder
        }
        let BidsNum = Number(await testContract.getBidsLength.call());                             // Check the number of hidden bids stored in the contract matches the number of bids
       expect(BidsNum).to.equal(bids.length);

        await time.increase(ONE_DAY + 1);
        await testContract.closeBiddingRound();

        for (let i = 0; i < bids.length; i++) {                                                          // Loop through each bid again for the bid reveal phase
            if (includeInvalidBid && i == 0) {                                                           // If includeInvalidBid is true and it's the first bid, attempt an invalid bid
                await truffleAssert.reverts(
                    bidInBidRevealRound(bids[i] - 1, minUsageTime[i], "some_salt", accounts[i + 1]),
                    " Actual bid and revealing bid do not match"
              );
               continue;
            }
           await bidInBidRevealRound(bids[i], minUsageTime[i], "some_salt", accounts[i + 1]);            // Otherwise, place a bid in the bid reveal round for each bidder
        }

       let highestBid = Number.MIN_SAFE_INTEGER;                                                         // Initialize with the smallest possible number
         let highestBidder = accounts[0];
         for (let i = 0; i < bids.length; i++) {
          let product = bids[i] * minUsageTime[i];
         if (product > highestBid) {
 
             highestBid = product;
             highestBidder = accounts[i+1];
         }
         }                                                                                              // Determine the highest bid and its bidder
         
         return { "bid": highestBid, "bidder": highestBidder};   
    };

    getBalance = async (account) => {
        return BigInt(await web3.eth.getBalance(account));
    };

    it("contract is initialized with correct parameters and deadlines", async () => {

        let Advertisement_Info  = await getAdvertisementInfo();
        // get the latest time using the Time helper function
        const latestTime = await time.latest();
        //verifying that the current parameter values of the advertisement matches the expected parameter values
        expect(Advertisement_Info.currentState).to.equal(STATE_READY_FOR_BIDS);
        expect(Advertisement_Info.PU).to.equal(PU_ACCOUNT);
        expect(Advertisement_Info.bandwidth).to.equal(BANDWIDTH);
        expect(Advertisement_Info.minBidValue).to.equal(MIN_BID_VALUE);
        expect(Advertisement_Info.depositValue).to.equal(DEPOSIT_VALUE);
        expect(Advertisement_Info.BidsDeadline).to.equal(latestTime.toNumber() + ONE_DAY);
        expect(Advertisement_Info.BidsRevealDeadline).to.equal(latestTime.toNumber() + (ONE_DAY * 2));
    });

    

    /////test cases to check the functionalities of bidInBiddingRound() function of the advertisement smart contract.
     
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


   

    /////test cases to verify the functionalities of closeBiddingRound() function of the advertisement smart contract.
    
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

   it("advertisement should close if no bids were recevied", async () => {
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
        //check whether the emitting event is ClosedAdvertisementWithNoBids 
        truffleAssert.eventEmitted(tx, "ClosedAdvertisementWithNoBids", (ev) => {
            return ev.whichRound == "Bidding round";
    });

    });

    it("advertisement should not be open for the bid revealing round if no bids were recevied", async () => {
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

    ////test cases to verify the functionalities of bidInBidRevealRound() function of the advertisement smart contract.
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

    it("cannot reveal bids in bid revealing round if deposit value does not match with revealed bid, time values.", async () => {
    await bidInBiddingRound(MIN_BID_VALUE, MIN_USAGE_TIME,accounts[1], DEPOSIT_VALUE);
    await time.increase(ONE_DAY + 1);
    await testContract.closeBiddingRound();
    ////checking whether the function reverts deposit value is lower than revealed bid x revealed time.
    await truffleAssert.reverts(
        testContract.bidInBidRevealRound(MIN_BID_VALUE*10,MIN_USAGE_TIME, "some_salt", { from: accounts[1] }),
        "Revealed bid values does not match with the deposit"
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


 //........................................................................................................................

    it("the advertisement should close if no valid bid reveals were received", async () => {

        await bidInBiddingRound(MIN_BID_VALUE + 1, MIN_USAGE_TIME, accounts[1], DEPOSIT_VALUE);                     // Simulate bidding in the bidding round of the advertisement
        await time.increase(ONE_DAY + 1);                                                                           // Increase time by one day plus one additional second
        await testContract.closeBiddingRound();                                                                     // Close the bidding round of the advertisement
    
        await truffleAssert.reverts(                                                                                // Verify that attempting to bid in the bid reveal round reverts with a specific message
            testContract.bidInBidRevealRound(MIN_BID_VALUE, MIN_USAGE_TIME, "some_salt", { from: accounts[1]}),
            "Actual bid and revealing bid do not match"
        );
    
        await time.increase(ONE_DAY + 1);                                                                           // Increase time by one day plus one additional second
        const tx = await testContract.closeAdvertisement();                                                               // Close the advertisement
    
        truffleAssert.eventEmitted(tx, "ClosedAdvertisementWithNoBids", (ev) => {                                         // Assert that the "ClosedAdvertisementWithNoBids" event is emitted with the correct parameters
            return ev.whichRound == "Bid revealing round, no valid bids";                                           // Updated event parameter to match the emitted event
        });
    
        const state = Number(await testContract.getCurrentState());                                                  // Get the current state of the contract and assert it's ready for deletion
        expect(state).to.equal(STATE_READY_FOR_DELETION);
    
        truffleAssert.eventEmitted(tx, "ClosedAdvertisementWithNoBids", (ev) =>
            ev.whichRound == "Bid revealing round, no valid bids");   // Assert again that the "ClosedAdvertisementWithNoBids" event is emitted with the correct parameters
    });

    it("closed bid reveal round", async () => {                                                           // Test case: Close bid reveal round
        await TestBidding(TEST_BIDS ,TEST_MIN_USAGE_TIME);                                                // Mock bidding with TEST_BIDS & TEST_MIN_USAGE_TIME
        await time.increase(ONE_DAY + 1);
        // await contract.setCurrentState(READY_FOR_OPEN_BIDS_STATE);
        const tx = await testContract.closeAdvertisement();
       
        let a = await getAdvertisementInfo();                                                                   // Get advertisement information and assert the current state is CLOSED_STATE
        expect(a.currentState).to.equal(STATE_CLOSED);
       truffleAssert.eventEmitted(tx, "ClosedRound", (ev) =>
         ev.whichRound == "Bid revealing round");                                                         // Assert that the "Bid revealing round" event is emitted with the correct parameters
    });

    it("cannot close bid reveal if in the wrong state", async () => {                                     // Test case: Cannot close bid reveal if in the wrong state
        await time.increase((ONE_DAY * 2) + 1);
        await truffleAssert.reverts(                                                                      // Verify that attempting to close the bid reveal round reverts with a specific message
            testContract.closeAdvertisement(),
            "Invalid state"
        )
    });
    
    it("cannot close bid reveal round before deadline", async () => {                         // Test case: Cannot close bid reveal round before deadline
        await testContract.setCurrentState(STATE_READY_FOR_BIDS_REVEAL);                      // Set the current state of the contract to READY_FOR_OPEN_BIDS_STATE
        await truffleAssert.reverts(                                                          // Verify that attempting to close the open round reverts with a specific message
            testContract.closeAdvertisement(),
            "Cannot perform this action before the deadline"
        )
    });

    it("found advertisement winner", async () => {                                                // Test case: Found advertisement winner
        const actualHighestBid = await TestBidding(TEST_BIDS,TEST_MIN_USAGE_TIME);          // Mock bidding with TEST_BIDS & TEST_MIN_USAGE_TIME and get the actual highest bid
        await time.increase(ONE_DAY + 1);
        await testContract.closeAdvertisement();
        const tx = await testContract.testFindWinner();                                     // Execute the function to find the winner
        
        const winner = await testContract.winner.call();                                    // Get the winner from the contract
    
        truffleAssert.eventEmitted(tx, "FoundHighestBid");                                  // Assert that the "FoundHighestBid" event is emitted
        expect(winner.accountAddress).to.equal(actualHighestBid.bidder);                    // Assert that the winner's account address and bid match the actual highest bid
        expect(Number(winner.bid)).to.equal(actualHighestBid.bid);
    });

    it("cannot find advertisement winner if in wrong state", async () => {
        await TestBidding(TEST_BIDS,TEST_MIN_USAGE_TIME);
        await time.increase(ONE_DAY + 1);
        
        await truffleAssert.reverts(
            testContract.testFindWinner(),
            "Invalid state"
        );
    });


    it("sent deposits back to bidders (all bids valid)", async () => {                              // Test case: Sent deposits back to bidders (all bids valid)
        const highestBid = await TestBidding(TEST_BIDS,TEST_MIN_USAGE_TIME);                        // Mock bidding with TEST_BIDS & TEST_MIN_USAGE_TIME and get the highest bid
        await time.increase(ONE_DAY + 1);
        await testContract.closeAdvertisement();
        await testContract.testFindWinner();
    
        const winner = await testContract.winner.call();                                            // Get the winner from the contract
        expect(winner.accountAddress).to.equal(highestBid.bidder);                                  // Assert that the winner's account address and bid match the highest bid
        expect(Number(winner.bid)).to.equal(highestBid.bid);
        
        let balancesBefore = [];                                                                    // Store balances of bidders before refunds
        for (let i = 0; i < TEST_BIDS.length; i++) {
            balancesBefore.push(await getBalance(accounts[i + 1]));
        }
    
        const tx = await testContract.testTransferBackDeposits();                                   // Execute the function to transfer back deposits
        truffleAssert.eventEmitted(tx, "TransferEvent");                                            // Assert that the "TransferEvent" event is emitted
    
        for (let i = 0; i < TEST_BIDS.length; i++) {                                                // Loop through each bidder
            const isWinner = accounts[i + 1] === winner.accountAddress;
            const currentBalance = await getBalance(accounts[i + 1]);
            
            const refundedValue = isWinner ? DEPOSIT_VALUE - (TEST_BIDS[i]*TEST_MIN_USAGE_TIME[i]) : DEPOSIT_VALUE;          // Calculate the refunded value based on whether the bidder is the winner or not
            expect(Number(currentBalance - balancesBefore[i])).to.equal(refundedValue);                                      // Assert that the difference in balances is equal to the refunded value
        }
    });

    it("did not send deposit back to invalid bidder", async () => {                     // Test case: Did not send deposit back to invalid bidder
        const invalidBidder = accounts[1];                                              // Define the invalid bidder
        await TestBidding(TEST_BIDS,TEST_MIN_USAGE_TIME ,true);                         // Mock bidding with TEST_BIDS & TEST_MIN_USAGE_TIME including an invalid first bid
        await testContract.setCurrentState(STATE_CLOSED);                               // Set the current state of the contract to CLOSED_STATE
        await testContract.testFindWinner();                                            // Execute the function to find the winner
    
        let balanceBefore = await getBalance(invalidBidder);      
                          // Get the balance of the invalid bidder before refund
        let tx = await testContract.testTransferBackDeposits();                         // Execute the function to transfer back deposits
        truffleAssert.eventEmitted(tx, "TransferEvent");                                // Assert that the "TransferEvent" event is emitted
        let balanceAfter = await getBalance(invalidBidder);                             // Get the balance of the invalid bidder after refund
        
        expect(Number(balanceAfter - balanceBefore)).to.equal(0);                       // Assert that the balance of the invalid bidder remains unchanged
    });

    // it("sent highest bid to PU, no extra deposits", async () => {                       // Test case: Sent highest bid to PU, no extra deposits
    //     const highestBid = await TestBidding(TEST_BIDS,TEST_MIN_USAGE_TIME);            // Mock bidding with TEST_BIDS & TEST_MIN_USAGE_TIME and get the highest bid
    //     await time.increase(ONE_DAY + 1);
    //     await testContract.closeAdvertisement();
    //     await testContract.testFindWinner();
    //     await testContract.testTransferBackDeposits();
        
    //     const balanceBefore = await getBalance(PU_ACCOUNT);                             // Get the balance of the PU before transferring highest bid
    //     const tx = await testContract.testTransferHighestBidToPU();                     // Execute the function to transfer highest bid to the PU
    //     truffleAssert.eventEmitted(tx, "TransferEvent");                                // Assert that the "TransferEvent" event is emitted
    //     const balanceAfter = await getBalance(PU_ACCOUNT);                              // Get the balance of the PU after transferring highest bid
    
    //     expect(Number(balanceAfter - balanceBefore)).to.equal(highestBid.bid);          // Assert that the difference in balances is equal to the highest bid
    // });
    
    // it("sent highest bid to PU, one extra deposit", async () => {                                       // Test case: Sent highest bid to PU, one extra deposit
    //     const highestBid = await TestBidding(TEST_BIDS, TEST_MIN_USAGE_TIME,true);                      // Mock bidding with TEST_BIDS & TEST_MIN_USAGE_TIME including an invalid first bid
    //     await time.increase(ONE_DAY + 1);
    //     await testContract.closeAdvertisement();
    //     await testContract.testFindWinner();
    //     await testContract.testTransferBackDeposits();
        
    //     const balanceBefore = BigInt(await web3.eth.getBalance(PU_ACCOUNT));                            // Get the balance of the PU before transferring highest bid to PU
    //     const tx = await testContract.testTransferHighestBidToPU({ gasPrice: 7});                       // Execute the function to transfer highest bid to PU
    //     truffleAssert.eventEmitted(tx, "TransferEvent");
    //     const balanceAfter = BigInt(await web3.eth.getBalance(PU_ACCOUNT));                             // Get the balance of the PU after transferring highest bid to PU
    
    //     expect(Number(balanceAfter - balanceBefore)).to.equal(highestBid.bid + DEPOSIT_VALUE);          // Assert that the difference in balances is equal to the highest bid plus one extra deposit
    // });

    it("winner retrieved token", async() => {                                                   // Test case: Winner retrieved token
        await TestBidding(TEST_BIDS, TEST_MIN_USAGE_TIME);
        await time.increase(ONE_DAY + 1);
        await testContract.closeAdvertisement();
        const winner = await testContract.winner.call();

        const tx = await testContract.retrieveToken({ from: winner.accountAddress });           // Execute the function for the winner to retrieve the token
        truffleAssert.eventEmitted(tx, "RetrievedToken");                                       // Assert that the "RetrievedToken" event is emitted
    });
    
    it("non-winner is not allowed to retrieve token", async() => {                              // Test case: Non-winner is not allowed to retrieve token
        await TestBidding(TEST_BIDS,TEST_MIN_USAGE_TIME);
        await time.increase(ONE_DAY + 1);
        await testContract.closeAdvertisement();
    
        await truffleAssert.reverts(                                                            // Verify that a non-winner attempting to retrieve the token reverts with a specific message
            testContract.retrieveToken({ from: accounts[1] }),
            "You are not the winner of the advertisement!"
        );
    });
    
    it("token should not be callable", async() => {
        await TestBidding(TEST_BIDS,TEST_MIN_USAGE_TIME);
        await time.increase(ONE_DAY + 1);
        await testContract.closeAdvertisement();
        
        try {
            await testContract.token.call();
            expect.fail();
        } catch(error) {
            expect(error.message).to.equal("Cannot read properties of undefined (reading 'call')");
        }
    });



    
});



