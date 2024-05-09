// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
import "./AdvertisementController.sol";


contract TestAdvertisementController is AdvertisementController {
    constructor() AdvertisementController() {}

    function testGetAdmin() public view returns (address) {
        return getAdmin();
    }
}