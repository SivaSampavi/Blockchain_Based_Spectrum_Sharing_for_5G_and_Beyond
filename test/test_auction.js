//importing TestAuction contract and other relevant libraries.
let Auction = artifacts.require("./TestAuction.sol");
const truffleAssert = require("truffle-assertions");
const { Time } = require("@openzeppelin/test-helpers");

//defining the tests within a contract block which provides access to etherium accounts.
contract("Auction", accounts => {
    //declare a variable to hold an instance of smart contract
    let testContract;
    //defining constant variables                               
    const PU_ACCOUNT = accounts[9];
    //definining constants for different states of the auction contract.
    const STATE_READY_FOR_BIDS = 0;
    const STATE_READY_FOR_BIDS_REVEAL = 1;
    const STATE_CLOSED= 2;
    const STATE_READY_FOR_DELETION = 3;

    const ONE_DAY = 86400;
    const BANDWIDTH = 200;
    const MIN_BID_VALUE = 50000;
    const DEPOSIT_VALUE = 100000;
    //defining an array for test bid values.
    const TEST_BIDS = [MIN_BID_VALUE , MIN_BID_VALUE + 1, MIN_BID_VALUE + 3, MIN_BID_VALUE + 4, MIN_BID_VALUE+2];
    //deploying the TestAuction contract before each test.
    beforeEach(async () => {
        //deploying an instance of the contract with specified parameters
        testContract = await Auction.new(
            PU_ACCOUNT,
            BANDWIDTH,
            MIN_BID_VALUE,
            DEPOSIT_VALUE,
            {
                gas: 4000000 //specify the gas limit for the deployment of the contract.
            }
        );
    });


    //tests

});

