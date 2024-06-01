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
}