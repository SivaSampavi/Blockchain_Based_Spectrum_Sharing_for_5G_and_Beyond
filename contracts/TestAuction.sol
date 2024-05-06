// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
import "./Auction.sol";

//defining a new smart contract because state cannot be modified directly. 
//state of the contract is determined during the execution of the trasactions.
//TestAuction contract inherits from Auction contract to test its functionalities.
contract TestAuction is Auction {
    constructor(
        address payable _PU,
        uint _bandwisth, 
        uint _minBidValue, 
        uint _depositValue
    ) Auction (
        _PU,
        _bandwisth, 
        _minBidValue, 
        _depositValue
    ) {}

    // function to set the current state of the auction directly.
    function setCurrentState(State newState) public {
        auctionInfo.currentState = newState;
    }

    //function to get the number of bidders from the stored array.
    function getBidsLength() public view returns(uint256) {
        return BidsAddresses.length;
    }

    //function to test finding the winner of the auction
    function testFindWinner() public {
        findWinner();
    }

    //function to test transferring back deposits to bidders
    function testTransferBackDeposits() public {
        transferBackDeposits();
    }

    //function to test transferring the highest bid to the PU
    function testTransferHighestBidToPU() public {
        transferHighestBidToPU();
    }

    function clearBidsAddresses() public {
        delete BidsAddresses;
    }
}
