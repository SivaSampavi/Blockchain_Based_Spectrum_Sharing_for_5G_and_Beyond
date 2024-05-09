// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./Advertisement.sol";

contract AdvertisementController {
    //Defining the state variables of advertisement controller Contract

    address private admin; 
    //Declare a variable to store the address of owner of the contract who is going to deploy the contract
    
    mapping(address => address) public PUAddresses;
    //Through this mapping the advertisement address is map to PU address to look up the PU address associated with a given advertisement address.

    event AddedNewAdvertisement(address advertisement);
    //Declare an event to emit, when a new advertisement is added to the system by taking the address of newly created advertisement
    
    event DeletedAdvertisement(address advertisement);
    //Declare an event to emit, when a aution is deleted from the system by taking the address of newly created advertisement

    constructor() {
        admin = msg.sender;
    }

    //fuction with these parameters
    function deployNewAdvertisement(
        address payable _PU, 
        uint _bandwidth, 
        uint _minBidValue,
        uint _depositValue
    ) public {
        // New instance of advertisement is created here
        Advertisement newAdvertisement = new Advertisement(
            _PU, 
            _bandwidth, 
            _minBidValue, 
            _depositValue
        );
        
        //This line associates the PU's address with the address of the newly created advertisement contract
        PUAddresses[address(newAdvertisement)] = _PU;

       //emitted to notify external entities that a new advertisement has been successfully added.
        emit AddedNewAdvertisement(address(newAdvertisement));
    }

    /// Advertisement cannot be deleted until either:
    ///     (1) Token has been retrieved
    ///     (2) Token has expired
    ///     (3) Advertisement has closed with no bids
    /// Advertisement can only be deleted by admin or by the advertisement PU
    
     
     // Function to delete an advertisement
     function deleteAdvertisement(address advertisementAddress) public {
         // Get the Advertisement contract instance using the provided address
         Advertisement advertisement = Advertisement(advertisementAddress);

         // Ensure that only the admin or the PU associated with the advertisement can delete it
         require(msg.sender == PUAddresses[advertisementAddress] || msg.sender == admin, "Can only be deleted by admin or the advertisement PU");
        
         // Check if the token associated with the advertisement has expired or has been retrieved
         bool tokenExpired = block.timestamp > advertisement.getTokenValidUntil() && advertisement.getTokenValidUntil() != 0;
         // If the token has not expired or been retrieved, ensure that the advertisement is in a state ready for deletion
         if (!tokenExpired) {
             require(advertisement.getCurrentState() == Advertisement.State.ReadyForDeletion, "Cannot delete advertisement before the token has expired or been retrieved");
         }
        
         // Call the deleteAdvertisement function of the Advertisement contract to delete it
         advertisement.deleteAdvertisement();
         // Remove the advertisement address from the list of PU addresses
         delete PUAddresses[advertisementAddress];

         // Emit an event indicating the deletion of the advertisement
         emit DeletedAdvertisement(advertisementAddress);
     }

     // Function to get the current timestamp
     function currentTime() internal view virtual returns(uint) {
         return block.timestamp;
     }

     // Function to get the address of the admin
     function getAdmin() internal view returns(address) {
         return admin;
     }
}