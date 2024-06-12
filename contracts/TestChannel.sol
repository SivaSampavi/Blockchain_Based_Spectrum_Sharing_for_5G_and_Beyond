//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./ChannelManager.sol";

contract TestChannel is ChannelManager {
    Advertisement public advertisement;
    ChannelManager public channelManager;

    event ContractDeployed(address indexed advertisement, address indexed channelManager);

    constructor( address payable _PU,
        uint _bandwidth, 
        uint _minBidValue, 
        uint _depositValue) {
        advertisement = new Advertisement( _PU, _bandwidth,  _minBidValue, _depositValue);
        channelManager = new ChannelManager();
        emit ContractDeployed(address(advertisement), address(channelManager));
    }

    function testOpenChannel() public payable {
        channelManager.openChannel{value: msg.value}(address(advertisement));
    }

    function testUpdatePayment() public returns (bool) {
        return channelManager.updatePayment(address(advertisement));
    }

   function testreadyToCloseChannel(bytes memory suSignature) public  {
        channelManager.readyToCloseChannel(address(advertisement),suSignature);
    }

    function testcloseChannel(bytes memory puSignature) public  {
       channelManager.closeChannel(address(advertisement),puSignature);
    }
    
}

