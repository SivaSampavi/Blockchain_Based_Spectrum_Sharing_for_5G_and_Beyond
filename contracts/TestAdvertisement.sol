// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
import "./Advertisement.sol";

//defining a new smart contract because state cannot be modified directly. 
//state of the contract is determined during the execution of the transactions.
//TestAdvertisement contract inherits from Advertisement contract to test its functionalities.
contract TestAdvertisement is Advertisement {
    constructor(
        address payable _PU,
        uint _bandwidth, 
        uint _minBidValue, 
        uint _depositValue
    ) Advertisement (
        _PU,
        _bandwidth, 
        _minBidValue, 
        _depositValue
    ) {}

    // function to set the current state of the advertisement directly.
    function setCurrentState(State newState) public {
        advertisementInfo.currentState = newState;
    }

    //function to get the number of bidders from the stored array.
    function getBidsLength() public view returns(uint256) {
        return BidsAddresses.length;
    }

    //function to test finding the winner of the advertisement
    function testFindWinner() public {
        findWinner();
    }

    //function to test transferring back deposits to bidders
    function testTransferBackDeposits() public {
        transferBackDeposits();
    }

    //function to clear all bid addresses
    function clearBidsAddresses() public {
        delete BidsAddresses;
    }

    //function to test transferring the highest bid to the PU
    // function testTransferHighestBidToPU() public {
    //     transferHighestBidToPU();
    // } 
}
