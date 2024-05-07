
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
import "./Auction.sol";

contract TestAuction is Auction {
    constructor(
        address payable _PU,
        uint _bandwidth, 
        uint _minBidValue, 
        uint _depositValue
    ) Auction (
        _PU,
        _bandwidth, 
        _minBidValue, 
        _depositValue
    ) {}

    function setCurrentState(State newState) public {
        auctionInfo.currentState = newState;
    }

    function getBidsLength() public view returns(uint256) {
        return BidsAddresses.length;
    }

    function testFindWinner() public {
        findWinner();
    }

    function testTransferBackDeposits() public {
        transferBackDeposits();
    }

    function testTransferHighestBidToPU() public {
        transferHighestBidToPU();
    }
}
