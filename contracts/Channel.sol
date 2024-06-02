// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

library ChannelLibrary {
    enum ChannelState {
        ReadyToOpen,
        Open,
        ReadyToClose,
        Closed
    }

    struct Channel {
        address payable secondaryUser;
        address payable primaryUser;
        uint puDeposit;
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

    function openChannel(
        Channel storage channel,
        address payable user,
        uint deposit,
        address winnerAccount,
        address advertisementPU,
        uint winnerBid,
        uint advertisementDepositValue
        
    ) internal {
        if (user == winnerAccount) {
            require(channel.secondaryUser == address(0), "Winner has already deposited");
            channel.secondaryUser = user;
            channel.lastPaymentTime = block.timestamp;
            channel.channelState = ChannelState.ReadyToOpen;
            emit ChannelOpened(user, advertisementPU, deposit, block.timestamp);
        } else if (user == advertisementPU) {
            require(deposit >= advertisementDepositValue, "Insufficient deposit from PU");
            require(channel.primaryUser == address(0), "PU has already deposited");
            channel.primaryUser = user;
            channel.puDeposit = deposit;
            channel.lastPaymentTime = block.timestamp;
            channel.channelState = ChannelState.ReadyToOpen;
            channel.totalPaid = winnerBid;
            emit ChannelOpened(winnerAccount, user, deposit, block.timestamp);
        }

        if (channel.secondaryUser != address(0) && channel.primaryUser != address(0)) {
            channel.channelState = ChannelState.Open;
            channel.initialTime = block.timestamp;
            emit ChannelFullyOpened(channel.secondaryUser, channel.primaryUser, block.timestamp);
        }
    }

    function updatePayment(
        Channel storage channel,
        uint usageTime,
        uint bidReveal,
        uint deposit
    ) internal returns (bool) {
        require(channel.channelState == ChannelState.Open, "Channel is not open");
        require(block.timestamp >= channel.lastPaymentTime + 1 minutes, "Can only update every 1 minute");

        uint spentTime = block.timestamp - channel.initialTime;

        if (spentTime > usageTime) {
            channel.totalPaid += bidReveal;
            channel.lastPaymentTime = block.timestamp;
        }

        bool isPaymentUpdateValid = channel.totalPaid <= deposit;
        emit TransferEvent("Payment update", channel.primaryUser, channel.totalPaid, block.timestamp);

        return isPaymentUpdateValid;
    }

    function readyToCloseChannel(
        Channel storage channel,
        address payable su,
        address winnerAccount,
        bytes memory suSignature
    ) internal {
        require(channel.channelState == ChannelState.Open, "Channel is not open");
        require(su == winnerAccount, "Only the winner can call ReadyToCloseChannel function");
        // Verify SU's signature
        bytes32 message = prefixed(keccak256(abi.encodePacked(address(this), su, channel.totalPaid, channel.lastPaymentTime)));
        require(recoverSigner(message, suSignature) == su, "Invalid SU signature");

        channel.channelState = ChannelState.ReadyToClose;
        emit ChannelReadyToClose(channel.secondaryUser, channel.primaryUser, channel.totalPaid, block.timestamp);
    }

    function closeChannel(
        Channel storage channel,
        address payable su,
        address pu,
        uint deposit,
        bytes memory puSignature
    ) internal {
        require(channel.channelState == ChannelState.ReadyToClose, "Channel is not ready to close yet");
        require(pu == channel.primaryUser, "Only the PU can fully close the channel");
        // Verify PU's signature
        bytes32 message = prefixed(keccak256(abi.encodePacked(address(this), su, channel.totalPaid, channel.lastPaymentTime)));
        require(recoverSigner(message, puSignature) == pu, "Invalid PU signature");

        channel.channelState = ChannelState.Closed;

        uint remainingDeposit = deposit - channel.totalPaid;
        if (remainingDeposit > 0) {
            channel.secondaryUser.transfer(remainingDeposit);
            channel.primaryUser.transfer(channel.totalPaid + channel.puDeposit);
        }

        emit ChannelClosed(channel.secondaryUser, channel.primaryUser, channel.totalPaid, block.timestamp);
    }

    // Signature verification functions
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function recoverSigner(bytes32 message, bytes memory sig) internal pure returns (address) {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);
        return ecrecover(message, v, r, s);
    }

    function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65, "Invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
