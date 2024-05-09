// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

contract Advertisement {
    enum State {
        ReadyForBids,//0th state
        ReadyForBidsReveal,//1st state
        Closed,//2nd state
        ReadyForDeletion//3rd state
    }

    //The following modifiers are the preconditions that should satisfy before a function execute

    //It checks if the current state of the advertisement matches the expected state provided as an argument to the function
    //It ensures that functions can only be executed when the advertisement is in the specified state.
    modifier inState(State expectedState) {
        require(advertisementInfo.currentState == expectedState, "Invalid state");
        _;
    }

    //ensures that functions can only be executed before a specified deadline
    //It checks the current block's timestamp against the provided deadline
    modifier isBeforeDeadline(uint deadline) {
        require(block.timestamp < deadline, "Cannot bid after deadline");
        _;
    }

    //ensures that functions can only be executed after a specified deadline. 
    //It checks whether the current block's timestamp is greater than the specified deadline.
    modifier isAfterDeadline(uint deadline) {
        require(block.timestamp > deadline, "Cannot perform this action before the deadline");
        _;
    }

    //This struct defines the parameters related to the advertisement
    struct AdvertisementInfo {
        State currentState;
        address payable PU;//PU account address
        uint bandwidth;//The amount of spectrum that is advertisemented off by the PU
        uint minBidValue;//The minimimum bidvalue that the PU will accept for this amount of bandwidth(in wei)
        uint depositValue;//The minimum deposit value which every bidder must transfer to the contract in order to participate in the advertisement(wei). 
        uint BidsDeadline;//bid closing time(s)
        uint BidsRevealDeadline;//Bid reveal closing time(s)
    }

    //Information related to a single bid
    struct Bid {
        bool existsBid;// states if a bid exists.
        bytes32 Bidding;//Will contain a hashed bid + minimum required usage time
        uint BidReveal;// Contains the bid, revealed bid
        uint minUsageTime ;//Contains the  revealed usage time
        bool isBidRevealValid;//defines if the bidreveal is valid or not
        uint deposit;//Contains the deposit amount of a bidder
        
    }

    //information about the winner of the Advertisement
    struct Winner {
        address accountAddress;//stores the address of the winner
        uint bid;//Stores the value of the winning bid
    }

    //represents a token related to the advertisement
    struct Token {
        address winner; //the address of the token winner
        address advertisementContract;//the address of the advertisement contract associated with the token
        uint bandwidth;//the bandwidth represented by the token
        uint validUntil;//the timestamp until which the token is valid
        bool isSpent;//indicating whether the token has been spent
    }

    address private controller;//ntended to store the address of the contract controller or owner
    AdvertisementInfo public advertisementInfo;//intended to store information about the current state and parameters of the advertisement.
    Winner public winner;//intended to store information about the winner of the advertisement.
    
    //This line declares a public mapping named bids, which associates address keys with Bid values. 
    //This mapping is likely used to keep track of bids made by different addresses in the advertisement.
    mapping(address => Bid) public bids;

    //used to manage tokens related to the advertisement, such as those awarded to the winner.
    mapping(address => Token) private token;

    //This array is likely intended to store the addresses of bidders who have submitted hidden bids in the advertisement
    address[] public BidsAddresses;

    //This event is emitted when a new advertisement is created. 
    //It includes information about the newly created advertisement.
    //It also includes the event emitted time
    event CreatedNewAdvertisement(AdvertisementInfo advertisementInfo, uint currentTime);

    //This event is emitted when a bid is received. 
    //It includes the address of the SU who placed the bid, the deposit amount and the event emitted time
    event ReceivedBid(address SU, uint deposit, uint currentTime);

    //This event is emitted when a open bid is received. 
    //It includes the address of the SU who placed the bid, the bidding amount , bidding time and the event emitted time
    event ReceivedBidReveal(address SU, uint bid,  uint UsageTime, uint currentTime );

    //This event is emitted when a round of bidding is closed. 
    //It includes information about which round of bidding is being closed, the current state of the advertisement
    //Also the event emitted time
    event ClosedRound(string whichRound, State state, uint currentTime);

    //This event is emitted when the advertisement is closed without receiving any bids. 
    //It includes information about which round of bidding has ended without any bids.
    event ClosedAdvertisementWithNoBids(string whichRound, uint currentTime);

    //This event is emitted when the highest bid is found during the advertisement. 
    //It includes information about the winner of the advertisement and the event emitted time.
    event FoundHighestBid(Winner winner, uint currentTime);

    //This event is emitted when the advertisement ends. 
    //It includes information about the winner of the advertisement, and the advertisement emitted time
    //Also the contractBalance (the balance of the contract at the end of the advertisement)
    event AdvertisementEnded(Winner winner, uint contractBalance, uint currentTime);

    //This event is emitted when a transfer of tokens or funds occurs within the contract. 
    //It includes information about the context of the transfer, the address where the tokens are being transferred to
    //Also the value of tokens being transferred, and the event emitted time.
    event TransferEvent(string context, address to, uint value, uint currentTime);
    
    //This event is emitted when tokens are retrieved from the contract. 
    //It includes information about who retrieved the tokens (retrievedBy) and evet emitted time
    event RetrievedToken(address retrievedBy, uint currentTime);

    // msg.sender is the controller controller and not the PU address
    // PU address must therefore be specified as a parameter
    constructor(
        address payable _PU, 
        uint _bandwidth, 
        uint _minBidValue, 
        uint _depositValue
    ) 
    
    {
        //assigns the address of the transaction sender (likely the person deploying the contract) to the controller variable. 
        //The controller variable stores the address of the contract's controller or owner.
        controller = msg.sender;
        //initializes the advertisementInfo struct with the provided values
        advertisementInfo = AdvertisementInfo({
            currentState: State.ReadyForBids,
            PU: _PU,
            bandwidth: _bandwidth,
            minBidValue: _minBidValue * 1 wei,
            depositValue: _depositValue * 1 wei,
            BidsDeadline: block.timestamp + 1 days,
            BidsRevealDeadline: block.timestamp + 2 days
        });
         // Emit CreatedNewAdvertisement event
        emit CreatedNewAdvertisement(advertisementInfo, block.timestamp);
    }

    
    //function to place bid in the first round.
    // Place a bid  by hashing it and minTime with keccak256().
     function bidInBiddingRound(bytes32 bid) public payable 
        inState(State.ReadyForBids)                                                 ////modifier to check whether the state is correct
        isBeforeDeadline(advertisementInfo.BidsDeadline)                                  ////modifier to check whether the bid is placing in the correct time.
        {
        require(msg.value >= advertisementInfo.depositValue, "Deposit value is too low"); //check whether the deposit value of SU is greater than or eqaul the minimum deposit value.
                                                                                    //a mapping to store the bid information along with SUs address
         bids[msg.sender] = Bid({                                                  
            existsBid: true,
            Bidding: bid,
            BidReveal: 0,
            minUsageTime:0,
            isBidRevealValid: false,
            deposit: msg.value * 1 wei
        });

        BidsAddresses.push(msg.sender);                                             //store addresses of bidder SUs in an array
        emit ReceivedBid(msg.sender, msg.value, block.timestamp);
    }

    //function to close the first round if the time for this round is up.

     function closeBiddingRound() public 
     inState(State.ReadyForBids)                                                    ////checking the state
     isAfterDeadline(advertisementInfo.BidsDeadline) {                                    //checking whether the time limit for placing bids are expired or not.
        if (BidsAddresses.length == 0) {                                            //If no bids were placed , close the advertisement.
            advertisementInfo.currentState = State.ReadyForDeletion;
             emit ClosedAdvertisementWithNoBids("Bidding round", block.timestamp);
        } else {                                                                    //else go for round 2 , BidReveal round
             advertisementInfo.currentState = State.ReadyForBidsReveal;
            emit ClosedRound("Bidding round", advertisementInfo.currentState, block.timestamp);
        }
     }


    //function to reveal the bidding amount and time for bidders.
     function bidInBidRevealRound(uint BidReveal,uint minUsageTime, string memory salt) public 
     inState(State.ReadyForBidsReveal) 
     isBeforeDeadline(advertisementInfo.BidsRevealDeadline) 
     {
         require(bids[msg.sender].existsBid, "This account has not bid in the bidding round"); //check whether the SU is a valid biddder
         require(BidReveal >= advertisementInfo.minBidValue, "Bid value is too low");                  //check whether the validity of the bid value
         require((BidReveal*minUsageTime) <= bids[msg.sender].deposit, "Revealed bid values does not match with the deposit");
         bytes32 hashedBid = keccak256(abi.encodePacked(BidReveal, minUsageTime , salt));        //Hashing bid + minUsage Time + salt value using  keccak256.
         require(bids[msg.sender].Bidding == hashedBid, " Actual bid and revealing bid do not match");        //checking whether the revealed bid information are match with the information provided in the bidding round.

         bids[msg.sender].isBidRevealValid = true;
         bids[msg.sender].BidReveal = BidReveal;                                                 //set the parameters of the bid.
         bids[msg.sender].minUsageTime = minUsageTime;

         emit ReceivedBidReveal(msg.sender, BidReveal, minUsageTime, block.timestamp);
     }



     //function to close the bid revealing round.
     function closeAdvertisement() public 
     isAfterDeadline(advertisementInfo.BidsRevealDeadline) 
     inState(State.ReadyForBidsReveal)
      {
         uint validBidReveals = 0;
         for (uint i = 0; i < BidsAddresses.length; i++) {
             if (bids[BidsAddresses[i]].isBidRevealValid) {                                           ////checking how many valid bid reveals are there.
                 validBidReveals += 1;
             }
         }
        
         if (validBidReveals == 0) {
             advertisementInfo.currentState = State.ReadyForDeletion;
            emit ClosedAdvertisementWithNoBids("Bid revealing round, no valid bids", block.timestamp);       ////if no any valid bid reveals close the advertisement.
        } else {
             advertisementInfo.currentState = State.Closed;
             emit ClosedRound("Bid revealing round", advertisementInfo.currentState, block.timestamp);  
            
             findWinner();                                                                             ////otherwise find the winner
           }
     }



    function findWinner() internal inState(State.Closed) {          // Function to find the winner of the advertisement
         address winnerAddress;                                     // Declaring variables to store the winner's address and the highest bid
         uint highestBid;

         for(uint i = 0; i < BidsAddresses.length; i++) {           // Loop through all the bids
             address SU = BidsAddresses[i];                         // Get the address of the bidder
             if (!bids[SU].isBidRevealValid) continue;                // Check if the bid is still open for this address; if not, skip to the next iteration
             uint bid = bids[SU].BidReveal*bids[SU].minUsageTime;   // Calculate the bid amount by multiplying the revealed bid with the minimum usage time

             if (bid > highestBid) {                                // Check if the current bid is higher than the previously recorded highest bid
                 winnerAddress = SU;                                // If yes, update the winner's address and the highest bid amount
                 highestBid = bid;        
             }
         }

         winner = Winner({                                          // Store the winner and their bid amount
             accountAddress: winnerAddress,
             bid: highestBid
         });
         emit FoundHighestBid(winner, block.timestamp);             // Emit an event to log the highest bid found

         token[winnerAddress] = Token({                             // Create a token for the winner with advertisement details
             winner: winnerAddress,
             advertisementContract: address(this),
             bandwidth: advertisementInfo.bandwidth,
             validUntil: block.timestamp + 12 weeks,
             isSpent: false
         });
     }

    function transferBackDeposits() internal inState(State.Closed) {                                        // Function to transfer back deposits to bidders
         require(winner.accountAddress != address(0), "Must find a winner before sending back deposits");   // Ensure that a winner has been found before proceeding

         for (uint i = 0; i < BidsAddresses.length; i++) {                                                  // Loop through all bidders
             address payable SUAddress = payable(BidsAddresses[i]);                                         // Get the address of the bidder and make it payable
             Bid memory bid = bids[SUAddress];                                                              // Get the bid details for the bidder

             if (!bid.isBidRevealValid) continue;                                                           // Do not send back deposit to invalid SUs

             bool isWinner = SUAddress == winner.accountAddress;                                            // Check if the bidder is the winner and if their bid reveal is greater than or equal to their deposit
             if (isWinner && bid.BidReveal >= bid.deposit) continue;
             uint deposit = isWinner ?  bid.deposit - bid.BidReveal*bid.minUsageTime : bid.deposit;         // Calculate the deposit to be transferred back

             emit TransferEvent(                                                                            // Emit an event indicating the transfer of deposit back to the bidder
                 "Transfer back deposit to SU", 
                 SUAddress, 
                 deposit, 
                 block.timestamp
             );

             SUAddress.transfer(deposit);                                                                   // Transfer the deposit back to the bidder
         }
     }

     function transferHighestBidToPU() internal inState(State.Closed) {                                         // Function to transfer the highest bid amount to the PU
         uint highestBid = winner.bid;                                                                          // Get the highest bid amount from the winner
         address payable PU = advertisementInfo.PU;                                                                   // Get the address of the PU
         string memory eventMsg = "Transfer highest bid to PU";                                                 // Initialize the event message

         if (highestBid > advertisementInfo.depositValue) {                                                           // Check if the highest bid exceeds the deposit value
             highestBid = advertisementInfo.depositValue;                                                             // If it does, set the highest bid to be equal to the deposit value
             eventMsg = "The highest bid was higher than the deposit value. Transferring the deposit to PU";    // Update the event message accordingly
         }

         emit TransferEvent(                                                    // Emit an event indicating the transfer of funds to the PU
             eventMsg,
             PU,
             highestBid,
             block.timestamp
         );

         PU.transfer(highestBid);                                               // Transfer the highest bid amount to the PU

         uint contractBalance = address(this).balance;                          // Transfer deposits of invalid SUs to PU
         if (contractBalance > 0) {
             emit TransferEvent(                                                // If there are remaining funds in the contract, transfer them to the PU
                 "Transfer contract balance to PU", 
                 PU, 
                 contractBalance,
                 block.timestamp
             );

             PU.transfer(contractBalance);                                      // Transfer the remaining funds to the PU
         }

         emit AdvertisementEnded(winner, address(this).balance, block.timestamp);     // Emit an event indicating the end of the advertisement
     }

     function retrieveToken() public inState(State.Closed) isAfterDeadline(advertisementInfo.BidsRevealDeadline) returns(Token memory) {      // Function to retrieve the token after the advertisement has closed and the deadline for bids reveal has passed
         require(msg.sender == winner.accountAddress, "You are not the winner of the advertisement!");                                        // Ensure that only the winner of the advertisement can retrieve the token
        
         advertisementInfo.currentState = State.ReadyForDeletion;                                                                             // Update the state of the advertisement to indicate readiness for deletion
         emit RetrievedToken(msg.sender, block.timestamp);                                                                              // Emit an event indicating the retrieval of the token by the winner

         return token[msg.sender];                                                                                                      // Return the token associated with the winner's address
     }

     function getAdvertisementInfo() public view returns(State, address, uint, uint, uint, uint, uint) {          // Function to retrieve information about the advertisement
         return (                                                                                           // Return the current state of the advertisement and its parameters
             advertisementInfo.currentState,
             advertisementInfo.PU,
             advertisementInfo.bandwidth,
             advertisementInfo.minBidValue,
             advertisementInfo.depositValue,
             advertisementInfo.BidsDeadline,
             advertisementInfo.BidsRevealDeadline
         );
     }

     function getCurrentState() public view returns(State) {                                // Function to get the current state of the advertisement
         return advertisementInfo.currentState;
     }

     function getTokenValidUntil() public view returns(uint) {                              // Function to get the validity period of the token for the advertisement winner
         return token[winner.accountAddress].validUntil;
     }

     function deleteAdvertisement() external {                                                    // Function to delete the advertisement contract
         require(msg.sender == controller, "You are not allowed to delete this advertisement!");  // Ensure that only the controller can delete the advertisement
         selfdestruct(advertisementInfo.PU);
     }
}
