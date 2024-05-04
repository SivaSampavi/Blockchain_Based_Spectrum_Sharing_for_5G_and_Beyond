// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./Auction.sol";

contract AuctionController {
    //Defining the state variables of auction controller Contract

    address private admin; 
    //Declare a variable to store the address of owner of the contract who is going to deploy the contract
    
    mapping(address => address) public PUAddresses;
    //Through this mapping the auction address is map to PU address to look up the PU address associated with a given auction address.

    event AddedNewAuction(address auction);
    //Declare an event to emit, when a new auction is added to the system by taking the address of newly created auction
    
    event DeletedAuction(address auction);
    //Declare an event to emit, when a aution is deleted from the system by taking the address of newly created auction

    constructor() {
        admin = msg.sender;
    }

    //fuction with these parameters
    function deployNewAuction(
        address payable _PU, 
        uint _bandwidth, 
        uint _minBidValue,
        uint _depositValue
    ) public {
        // New instance of auction is created here
        Auction newAuction = new Auction(
            _PU, 
            _bandwidth, 
            _minBidValue, 
            _depositValue
        );
        
        //This line associates the PU's address with the address of the newly created auction contract
        PUAddresses[address(newAuction)] = _PU;

       //emitted to notify external entities that a new auction has been successfully added.
        emit AddedNewAuction(address(newAuction));
    }

    /// Auction cannot be deleted until either:
    ///     (1) Token has been retrieved
    ///     (2) Token has expired
    ///     (3) Auction has closed with no bids
    /// Auction can only be deleted by admin or by the auction PU
    // function deleteAuction(address auctionAddress) public {
    //     Auction auction = Auction(auctionAddress);

    //     require(msg.sender == PUAddresses[auctionAddress] || msg.sender == admin, "Can only be deleted by admin or the auction PU");
        
    //     bool tokenExpired = currentTime() > auction.getTokenValidUntil() && auction.getTokenValidUntil() != 0;
    //     if (!tokenExpired) {
    //         require(auction.getCurrentState() == Auction.State.ReadyForDeletion, "Cannot delete auction before the token has expired or been retrieved");
    //     }
        
    //     auction.deleteAuction();
    //     delete PUAddresses[auctionAddress];

    //     emit DeletedAuction(auctionAddress);
    // }

    // function currentTime() internal view virtual returns(uint) {
    //     return block.timestamp;
    // }

    // function getAdmin() internal view returns(address) {
    //     return admin;
    // }
}