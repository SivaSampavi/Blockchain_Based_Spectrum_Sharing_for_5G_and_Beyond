// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

contract Auction {
    enum State {
        ReadyForBids,//0th state
        ReadyForBidsReveal,//1st state
        Closed,//2nd state
        ReadyForDeletion//3rd state
    }

    //The following modifiers are the preconditions that should satisfy before a function execute

    //It checks if the current state of the auction matches the expected state provided as an argument to the function
    //It ensures that functions can only be executed when the auction is in the specified state.
    modifier inState(State expectedState) {
        require(auctionInfo.currentState == expectedState, "Invalid state");
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

    //This struct defines the parameters related to the auction
    struct AuctionInfo {
        State currentState;
        address payable PU;//PU account address
        uint bandwidth;//The amount of spectrum that is auctioned off by the PU
        uint minBidValue;//The minimimum bidvalue that the PU will accept for this amount of bandwidth(in wei)
        uint depositValue;//The minimum deposit value which every bidder must transfer to the contract in order to participate in the auction(wei). 
        uint BidsDeadline;//bid closing time(s)
        uint BidsRevealDeadline;//Bid reveal closing time(s)
    }

    //Information related to a single bid
    struct Bid {
        bool existsBid;// states if a bid exists.
        bytes32 Bid;//Will contain a hashed bid
        uint BidReveal;// Contains the bid, revealed bid
        bool isBidRevealValid;//defines if the bidreveal is valid or not
        uint deposit;//Contains the deposit amount of a bidder
        uint minUsageTime;//Contains the minimum required usage time
    }

    //information about the winner of the auction
    struct Winner {
        address accountAddress;//stores the address of the winner
        uint bid;//Stores the value of the winning bid
    }

    //represents a token related to the auction
    struct Token {
        address winner; //the address of the token winner
        address auctionContract;//the address of the auction contract associated with the token
        uint bandwidth;//the bandwidth represented by the token
        uint validUntil;//the timestamp until which the token is valid
        bool isSpent;//indicating whether the token has been spent
    }

    address private controller;//ntended to store the address of the contract controller or owner
    AuctionInfo public auctionInfo;//intended to store information about the current state and parameters of the auction.
    Winner public winner;//intended to store information about the winner of the auction.
    
    //This line declares a public mapping named bids, which associates address keys with Bid values. 
    //This mapping is likely used to keep track of bids made by different addresses in the auction.
    mapping(address => Bid) public bids;

    //used to manage tokens related to the auction, such as those awarded to the winner.
    mapping(address => Token) private token;

    //This array is likely intended to store the addresses of bidders who have submitted hidden bids in the auction
    address[] public BidsAddresses;

    //This event is emitted when a new auction is created. 
    //It includes information about the newly created auction.
    //It also includes the event emitted time
    event CreatedNewAuction(AuctionInfo auctionInfo, uint currentTime);

    //This event is emitted when a bid is received. 
    //It includes the address of the SU who placed the bid, the deposit amount.
    //Also the event emitted time, and the minimum required usage time.
    event ReceivedBid(address SU, uint deposit, uint currentTime, uint minuUsageTime);

    //This event is emitted when a open bid is received. others are same as previous
    event ReceivedBidReveal(address SU, uint bid, uint currentTime,  uint minuUsageTime);

    //This event is emitted when a round of bidding is closed. 
    //It includes information about which round of bidding is being closed, the current state of the auction
    //Also the event emitted time
    event ClosedRound(string whichRound, State state, uint currentTime);

    //This event is emitted when the auction is closed without receiving any bids. 
    //It includes information about which round of bidding has ended without any bids.
    event ClosedAuctionWithNoBids(string whichRound, uint currentTime);

    //This event is emitted when the highest bid is found during the auction. 
    //It includes information about the winner of the auction and the event emitted time.
    event FoundHighestBid(Winner winner, uint currentTime);

    //This event is emitted when the auction ends. 
    //It includes information about the winner of the auction, and the auction emitted time
    //Also the contractBalance (the balance of the contract at the end of the auction)
    event AuctionEnded(Winner winner, uint contractBalance, uint currentTime);

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
        //initializes the auctionInfo struct with the provided values
        auctionInfo = AuctionInfo({
            currentState: State.ReadyForBids,
            PU: _PU,
            bandwidth: _bandwidth,
            minBidValue: _minBidValue * 1 wei,
            depositValue: _depositValue * 1 wei,
            BidsDeadline: block.timestamp + 1 days,
            BidsRevealDeadline: block.timestamp + 2 days
        });
         // Emit CreatedNewAuction event
        emit CreatedNewAuction(auctionInfo, block.timestamp);
    }

    // /// Place a bid by hashing it with keccak256().
    // /// The deposit is only refunded if the bid is above the minimum bid value, 
    // /// and if the open bid equals the hashed bid during the open round
    // function bidInHiddenRound(bytes32 bid) public payable 
    //     inState(State.ReadyForBids) 
    //     isBeforeDeadline(auctionInfo.BidsDeadline) 
    // {
    //     require(msg.value >= auctionInfo.depositValue, "Deposit value is too low");

    //     bids[msg.sender] = Bid({
    //         existsBid: true,
    //         hiddenBid: bid,
    //         BidReveal: 0,
    //         isBidRevealValid: false,
    //         deposit: msg.value * 1 wei
    //     });

    //     BidsAddresses.push(msg.sender);
    //     emit ReceivedHiddenBid(msg.sender, msg.value, block.timestamp);
    // }

    // function closeHiddenRound() public inState(State.ReadyForBids) isAfterDeadline(auctionInfo.BidsDeadline) {
    //     if (BidsAddresses.length == 0) {
    //         auctionInfo.currentState = State.ReadyForDeletion;
    //         emit ClosedAuctionWithNoBids("Hidden round", block.timestamp);
    //     } else {
    //         auctionInfo.currentState = State.ReadyForBidsReveal;
    //         emit ClosedRound("Hidden round", auctionInfo.currentState, block.timestamp);
    //     }
    // }

    // function bidInOpenRound(uint BidReveal, string memory salt) public inState(State.ReadyForBidsReveal) isBeforeDeadline(auctionInfo.BidsRevealDeadline) {
    //     require(bids[msg.sender].existsBid, "This account has not bidden in the hidden round");
    //     require(BidReveal >= auctionInfo.minBidValue, "Bid value is too low");

    //     bytes32 hashedBid = keccak256(abi.encodePacked(BidReveal, salt));
    //     require(bids[msg.sender].hiddenBid == hashedBid, "Open bid and bid do not match");

    //     bids[msg.sender].isBidRevealValid = true;
    //     bids[msg.sender].BidReveal = BidReveal;
    //     emit ReceivedOpenBid(msg.sender, BidReveal, block.timestamp);
    // }

    // function closeOpenRound() public inState(State.ReadyForBidsReveal) isAfterDeadline(auctionInfo.BidsRevealDeadline) {
    //     uint validOpenBids = 0;
    //     for (uint i = 0; i < BidsAddresses.length; i++) {
    //         if (bids[BidsAddresses[i]].isBidRevealValid) {
    //             validOpenBids += 1;
    //         }
    //     }
        
    //     if (validOpenBids == 0) {
    //         auctionInfo.currentState = State.ReadyForDeletion;
    //         emit ClosedAuctionWithNoBids("Open round, no valid bids", block.timestamp);
    //     } else {
    //         auctionInfo.currentState = State.Closed;
    //         emit ClosedRound("Open round", auctionInfo.currentState, block.timestamp);
    //     }
    // }

    // function closeAuction() public isAfterDeadline(auctionInfo.BidsRevealDeadline) inState(State.ReadyForBidsReveal) {
    //     uint validOpenBids = 0;
    //     for (uint i = 0; i < BidsAddresses.length; i++) {
    //         if (bids[BidsAddresses[i]].isBidRevealValid) {
    //             validOpenBids += 1;
    //         }
    //     }
        
    //     if (validOpenBids == 0) {
    //         auctionInfo.currentState = State.ReadyForDeletion;
    //         emit ClosedAuctionWithNoBids("Open round, no valid bids", block.timestamp);
    //     } else {
    //         auctionInfo.currentState = State.Closed;
    //         emit ClosedRound("Open round", auctionInfo.currentState, block.timestamp);
            
    //         findWinner();
    //     }
    // }

    // function findWinner() internal inState(State.Closed) {
    //     address winnerAddress;
    //     uint highestBid;

    //     for(uint i = 0; i < BidsAddresses.length; i++) {
    //         address SU = BidsAddresses[i];
    //         uint bid = bids[SU].BidReveal;

    //         if (bid > highestBid) {
    //             winnerAddress = SU;
    //             highestBid = bid;
    //         }
    //     }

    //     winner = Winner({
    //         accountAddress: winnerAddress,
    //         bid: highestBid
    //     });
    //     emit FoundHighestBid(winner, block.timestamp);

    //     token[winnerAddress] = Token({
    //         winner: winnerAddress,
    //         auctionContract: address(this),
    //         bandwidth: auctionInfo.bandwidth,
    //         validUntil: block.timestamp + 12 weeks,
    //         isSpent: false
    //     });
    // }

    // function transferBackDeposits() internal inState(State.Closed) {
    //     require(winner.accountAddress != address(0), "Must find a winner before sending back deposits");

    //     for (uint i = 0; i < BidsAddresses.length; i++) {
    //         address payable SUAddress = payable(BidsAddresses[i]);
    //         Bid memory bid = bids[SUAddress];

    //         // Do not send back deposit to invalid SUs
    //         if (!bid.isBidRevealValid) continue; 

    //         bool isWinner = SUAddress == winner.accountAddress;
    //         if (isWinner && bid.BidReveal >= bid.deposit) continue;
    //         uint deposit = isWinner ?  bid.deposit - bid.BidReveal : bid.deposit;

    //         emit TransferEvent(
    //             "Transfer back deposit to SU", 
    //             SUAddress, 
    //             deposit, 
    //             block.timestamp
    //         );

    //         SUAddress.transfer(deposit);
    //     }
    // }

    // function transferHighestBidToPU() internal inState(State.Closed) {
    //     uint highestBid = winner.bid;
    //     address payable PU = auctionInfo.PU;
    //     string memory eventMsg = "Transfer highest bid to PU";

    //     if (highestBid > auctionInfo.depositValue) {
    //         highestBid = auctionInfo.depositValue;
    //         eventMsg = "The highest bid was higher than the deposit value. Transferring the deposit to PU";
    //     }

    //     emit TransferEvent(
    //         eventMsg,
    //         PU,
    //         highestBid,
    //         block.timestamp
    //     );

    //     PU.transfer(highestBid);

    //     // Transfer deposits of invalid SUs to PU
    //     uint contractBalance = address(this).balance;
    //     if (contractBalance > 0) {
    //         emit TransferEvent(
    //             "Transfer contract balance to PU", 
    //             PU, 
    //             contractBalance,
    //             block.timestamp
    //         );

    //         PU.transfer(contractBalance);
    //     }

    //     emit AuctionEnded(winner, address(this).balance, block.timestamp);
    // }

    // function retrieveToken() public inState(State.Closed) isAfterDeadline(auctionInfo.BidsRevealDeadline) returns(Token memory) {
    //     require(msg.sender == winner.accountAddress, "You are not the winner of the auction!");
        
    //     auctionInfo.currentState = State.ReadyForDeletion;
    //     emit RetrievedToken(msg.sender, block.timestamp);

    //     return token[msg.sender];
    // }

    // function getAuctionInfo() public view returns(State, address, uint, uint, uint, uint, uint) {
    //     return (
    //         auctionInfo.currentState,
    //         auctionInfo.PU,
    //         auctionInfo.bandwidth,
    //         auctionInfo.minBidValue,
    //         auctionInfo.depositValue,
    //         auctionInfo.BidsDeadline,
    //         auctionInfo.BidsRevealDeadline
    //     );
    // }

    // function getCurrentState() public view returns(State) {
    //     return auctionInfo.currentState;
    // }

    // function getTokenValidUntil() public view returns(uint) {
    //     return token[winner.accountAddress].validUntil;
    // }

    // function deleteAuction() external {
    //     require(msg.sender == controller, "You are not allowed to delete this auction!");
    //     selfdestruct(auctionInfo.PU);
    // }
}