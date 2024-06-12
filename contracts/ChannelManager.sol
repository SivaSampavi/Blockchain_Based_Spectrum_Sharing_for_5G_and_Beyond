// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./Advertisement.sol";


contract ChannelManager {
    enum ChannelState {
        ReadyToOpen,
        Open,
        ReadyToClose,
        Closed
    }

    struct Channel {
        address payable secondaryUser;
        address payable primaryUser;
        
        uint initialTime;
        uint lastPaymentTime;
        uint totalPaid;
        ChannelState channelState;
    }

    event ChannelOpened(address SU, address PU, uint deposit, uint currentTime);
    event ChannelFullyOpened(address secondaryUser, address primaryUser, uint currentTime);
    event TransferEvent(string context, address to, uint value, uint currentTime);
    event ChannelReadyToClose(address secondaryUser, address primaryUser, uint totalPaid, uint currentTime);
    event ChannelClosed(address secondaryUser, address primaryUser, uint totalPaid, uint currentTime);

   
    mapping(address => Channel) public channels;



    function openChannel(address advertisementAddress) public payable {

        Advertisement advertisement = Advertisement(advertisementAddress);
        (address winnerAddress, uint highestBid) = advertisement.getWinner();
        (, address PU, , , uint requiredPUDeposit, , ) = advertisement.getAdvertisementInfo();

        require(advertisement.getCurrentState() == Advertisement.State.ReadyForPayment, "Cannot open a channel before the token has been retrieved");

        Channel storage channel = channels[winnerAddress];

        require(msg.sender == winnerAddress || msg.sender == PU, "Only the winner or PU can open a payment channel");

        if (msg.sender == winnerAddress) {
            require(channel.secondaryUser == address(0), "Winner has already deposited");

            channel.secondaryUser = payable(msg.sender);
            channel.lastPaymentTime = block.timestamp;
            channel.channelState = ChannelState.ReadyToOpen;

            emit ChannelOpened(msg.sender, PU, msg.value, block.timestamp);
        } else if (msg.sender == PU) {
            require(msg.value >= requiredPUDeposit, "Insufficient deposit from PU");
            require(channel.primaryUser == address(0), "PU has already deposited");

            channel.primaryUser = payable(msg.sender);
            
            channel.lastPaymentTime = block.timestamp;
            channel.channelState = ChannelState.ReadyToOpen;
            channel.totalPaid = highestBid;

            emit ChannelOpened(winnerAddress, msg.sender, msg.value, block.timestamp);
        }

        if (channel.secondaryUser != address(0) && channel.primaryUser != address(0)) {
            channel.channelState = ChannelState.Open;
            channel.initialTime = block.timestamp;

            emit ChannelFullyOpened(channel.secondaryUser, channel.primaryUser, block.timestamp);
        }
    }

    function updatePayment(address advertisementAddress) public returns (bool) {

         
        Advertisement advertisement = Advertisement(advertisementAddress);
        (address winnerAddress, ) = advertisement.getWinner();
        
        Channel storage channel = channels[winnerAddress];
        (uint minUsageTime, uint minBidValue, uint depositValue) = advertisement.getBidInfo(winnerAddress);

       

        require(channel.channelState == ChannelState.Open, "Channel is not open");
        require(block.timestamp >= channel.lastPaymentTime + 1 minutes, "Can only update every 1 minute");

        uint spentTime = block.timestamp - channel.initialTime;

        if (spentTime > minUsageTime) {
            channel.totalPaid += minBidValue; // Assuming BidReveal represents the min usage time or a similar concept
            channel.lastPaymentTime = block.timestamp;
        }

        bool isPaymentUpdateValid = channel.totalPaid <= depositValue;

        emit TransferEvent("Payment update", channel.primaryUser, channel.totalPaid, block.timestamp);

        return isPaymentUpdateValid;
    }

    function readyToCloseChannel(address advertisementAddress,bytes memory suSignature) public {
        Advertisement advertisement = Advertisement(advertisementAddress);
        (address winnerAddress, ) = advertisement.getWinner();
        Channel storage channel = channels[winnerAddress];

        require(channel.channelState == ChannelState.Open, "Channel is not open");
        require(msg.sender == winnerAddress, "Only the winner can call ReadyToCloseChannel function");

        bytes32 message = prefixed(keccak256(abi.encodePacked(address(this), winnerAddress, channel.totalPaid, channel.lastPaymentTime)));

        require(recoverSigner(message, suSignature) == winnerAddress, "Invalid SU signature");

        channel.channelState = ChannelState.ReadyToClose;

        emit ChannelReadyToClose(channel.secondaryUser, channel.primaryUser, channel.totalPaid, block.timestamp);
    }

    function closeChannel(address advertisementAddress,bytes memory puSignature) public {
        Advertisement advertisement = Advertisement(advertisementAddress);
         (, address PU, , , , , ) = advertisement.getAdvertisementInfo();
        (address winnerAddress, ) = advertisement.getWinner();
         (,, uint depositValue) = advertisement.getBidInfo(winnerAddress);

        Channel storage channel = channels[winnerAddress];

        require(channel.channelState == ChannelState.ReadyToClose, "Channel is not ready to close yet");
        require(msg.sender == PU, "Only the PU can fully close the channel");

        bytes32 message = prefixed(keccak256(abi.encodePacked(address(this),PU, channel.totalPaid, channel.lastPaymentTime)));

        require(recoverSigner(message, puSignature) == PU, "Invalid PU signature");

        channel.channelState = ChannelState.Closed;

        uint remainingDeposit = depositValue - channel.totalPaid;
        if (remainingDeposit > 0) {
            channel.secondaryUser.transfer(remainingDeposit);
            channel.primaryUser.transfer(channel.totalPaid );
        }

        emit ChannelClosed(channel.secondaryUser, channel.primaryUser, channel.totalPaid, block.timestamp);
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function recoverSigner(bytes32 message, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Invalid signature recovery");

        return ecrecover(message, v, r, s);
    }
}
