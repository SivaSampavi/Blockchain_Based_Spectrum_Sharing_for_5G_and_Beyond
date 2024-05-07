// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
import "./AuctionController.sol";


contract TestAuctionController is AuctionController {
    constructor() AuctionController() {}

    function testGetAdmin() public view returns (address) {
        return getAdmin();
    }
}