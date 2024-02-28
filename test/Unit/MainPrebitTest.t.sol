// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {MainPrebit} from "../../src/Main.sol";
import {DeployPrebit} from "../../script/DeployMain.s.sol";
import {PrebitReferrals} from "../../src/PrebitReferrals.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MainPrebitInjector} from "../../src/Injector.sol";
import {PrebitBonusToken} from "../../src/BonusToken/WUSD.sol";
import {Attacker} from "../../src/Attacker.sol";

contract MainPrebitTest is StdCheats, Test {
    struct Referrals {
        uint256 code;
        address parent;
        address tparent;
        bool valid;
    }

    struct RowData {
        uint256 amountInRow;
        uint256 cardsInRow;
        uint256 rewardEachCard;
    }
    DeployPrebit deployer;
    MainPrebit mainPrebit;
    PrebitReferrals referrals;
    ERC20Mock tokenMock;
    PrebitBonusToken bounsToken;
    Attacker attacker;
    Referrals reffer;

    address public USER = makeAddr("USER");
    address public PARENT = makeAddr("PARRENT");
    address public OWNER;
    address payable HACKER;

    uint256 public constant INITIAL_BALANCE = 200000000000000000000; // initial payToken(USDT,BUSD,...) balance, 200$
    uint256 public constant CURRENT_BTC_PRICE = 10000000; // 2 decimals 1BTC = 10000.00 usd
    uint256 openTimestamp = 1709134167; // current timestamp entered manually

    uint256[] public BTC_PREDICTION_PRICES = [
        10000000,
        10000001,
        10000002,
        10000003,
        10000004,
        10000005,
        10000006,
        10000007,
        10000008,
        10000009
    ]; //predictions 10 number from 10000.01 usd to 10000.09 usd

    function setUp() public {
        deployer = new DeployPrebit();
        //attacker
        (mainPrebit, referrals, tokenMock, bounsToken, attacker) = deployer
            .run();
        tokenMock.mint(USER, INITIAL_BALANCE);
        HACKER = payable(makeAddr("0x1234"));
        OWNER = mainPrebit.owner();
    }

    modifier startGenesisPreBit() {
        vm.startPrank(OWNER);
        mainPrebit.startNextPrebitGenesis(
            100,
            openTimestamp + 3600 + 100, // 1hour from now
            openTimestamp,
            openTimestamp + 3600
        );
        _;
    }

    function testUserCanPurchasePrecard() public startGenesisPreBit {
        //Arrange
        //start genesis PreBit
        uint256 Id = mainPrebit.currentPreBitId();
        vm.stopPrank();
        //get refferal code for user
        vm.startPrank(USER);
        referrals.generateReferralCode(1);
        uint256 referralCode = referrals.getUserReferralCode(USER);
        // purchase precard for USER
        tokenMock.approve(address(mainPrebit), 10 * mainPrebit.precardPrice());
        mainPrebit.purchasePrecard(Id, BTC_PREDICTION_PRICES, referralCode, 0);
        uint256[] memory expectedNumberOfPrecards;
        expectedNumberOfPrecards = mainPrebit.getUserPreCardIDs(USER, Id);
        assertEq(expectedNumberOfPrecards.length, BTC_PREDICTION_PRICES.length);
    }

    modifier startGenesisPreBitAndBuyPrecards() {
        vm.startPrank(OWNER); // start prank as owner,
        mainPrebit.startNextPrebitGenesis(
            100,
            openTimestamp + 3600 + 100, // 1hour from now
            openTimestamp,
            openTimestamp + 3600
        );
        // get the current prebit id
        uint256 Id = mainPrebit.currentPreBitId();
        vm.stopPrank();

        /// generate Refferal Codes for user and parent
        //get refferal code for parrent
        vm.startPrank(PARENT);
        referrals.generateReferralCode(1);
        uint256 parentReferralCode = referrals.getUserReferralCode(PARENT);
        vm.stopPrank();
        //get refferal code for user
        vm.startPrank(USER);
        referrals.generateReferralCode(parentReferralCode);
        uint256 referralCode = referrals.getUserReferralCode(USER);
        address parent = referrals.getUserParent(USER);
        assertEq(parent, PARENT); // assert if user parent is same as PARENT address

        // purchase precard for USER
        tokenMock.approve(address(mainPrebit), 10 * mainPrebit.precardPrice());
        uint256 userBalanceBeforePurchase = tokenMock.balanceOf(USER);
        console.log("balance before purchase:", userBalanceBeforePurchase);
        //purcahse 10 precards for 10*2 = 20 usd
        mainPrebit.purchasePrecard(Id, BTC_PREDICTION_PRICES, referralCode, 0);
        vm.stopPrank();
        _;
    }

    function testWinnerIsPickedAndGetsThePrize()
        public
        startGenesisPreBitAndBuyPrecards
    {
        // get Id for current prebit
        uint256 Id = mainPrebit.currentPreBitId();
        // warp time to 1 hour after  end prebit after purchase of tickets
        // also rol the blocknumber to avoid any problems.
        vm.warp(openTimestamp + 3600 + 100 + 1);
        vm.roll(block.number + 10);
        // end the prebit by calling execute function
        mainPrebit.executeDrawFinalPrice(Id, CURRENT_BTC_PRICE, 10);

        // get the winnings by parnking the user and calling claim function
        vm.startPrank(USER);
        uint256 userBalanceBefore = tokenMock.balanceOf(USER);
        mainPrebit.claimRewardPrebit(Id);
        uint256 userBalanceAfter = tokenMock.balanceOf(USER);
        // logs to check user winning amount
        console.log("balance before winning:", userBalanceBefore);
        console.log("balance after winning:", userBalanceAfter);
        // assert if the winning amount is greater than zero
        assert(userBalanceBefore <= userBalanceAfter);
    }

    function testCheckProtocolSpendingPattern()
        public
        startGenesisPreBitAndBuyPrecards
    {
        // this function is just to check how the money that comes into the protocol is transferred to Refferals, Treasuries, and Pot.
        // noting else is checked for more data about this read the readme file
        uint256 Id = mainPrebit.currentPreBitId();
        // balance after purchase and before draw
        uint256 treasuryBalance2 = mainPrebit.getCurrentAmountInAllRows();
        console.log("Treasury after purchase:", treasuryBalance2);

        // time passes and winners are drawn
        vm.warp(openTimestamp + 7200);
        vm.roll(block.number + 1);
        mainPrebit.executeDrawFinalPrice(Id, CURRENT_BTC_PRICE, 5);
        //
        uint256 treasuryBalance3 = mainPrebit.getCurrentAmountInAllRows();
        console.log("Treasury after win:", treasuryBalance3);
        uint256 parentbalanceafter = tokenMock.balanceOf(PARENT);
        console.log("balance of parent after purchase:", parentbalanceafter);
        console.log("sumOfBalances = ", parentbalanceafter + treasuryBalance2);
    }

    function testRugPull() public startGenesisPreBitAndBuyPrecards {
        /** in this function using the attacker.sol which is a copy
         *  of the mainPrebit.sol but with a function which can empty
         *  the contract from all fudns, we case show the process to
         *  how the protocol owner can do a rug pull
         */

        uint256 Id = mainPrebit.currentPreBitId();
        // warp time and end the prebit and roll the block number
        vm.warp(openTimestamp + 3600 + 101);
        vm.roll(block.number + 1);
        //ending the current prebit
        mainPrebit.executeDrawFinalPrice(Id, CURRENT_BTC_PRICE, 10);
        vm.prank(USER);
        //claiming rewards - even this process may not be necessary owner might be able to empty the contract without paying the winners, ive not tested it yet:)
        mainPrebit.claimRewardPrebit(Id);

        uint256 mainContractBalanceBeforeMigration = tokenMock.balanceOf(
            address(mainPrebit)
        );
        uint256 rugPullContractBalanceBeforeMigration = tokenMock.balanceOf(
            address(attacker)
        );
        // asserts if the initial balance of the main contract if zero
        assert(mainContractBalanceBeforeMigration != 0);
        console.log(
            "Contract 1 Balance Before Migration:",
            mainContractBalanceBeforeMigration
        );
        console.log(
            "Contract 2 Balance Before Migration:",
            rugPullContractBalanceBeforeMigration
        );
        // migrating the main contract to the attacker(rug pull) contract as owner address
        vm.startPrank(OWNER);
        mainPrebit.migrateToNewVersion(address(attacker));
        // checking the balances again
        uint256 mainContractBalanceAfterMigration = tokenMock.balanceOf(
            address(mainPrebit)
        );
        console.log(
            "Contract 1 Balance after Migration:",
            mainContractBalanceAfterMigration
        );
        uint256 rugPullContractBalanceAfterMigration = tokenMock.balanceOf(
            address(attacker)
        );
        console.log(
            "Contract 2 Balance after Migration:",
            rugPullContractBalanceAfterMigration
        );
        // checking to see if the contract is completely migrated to new contract
        assertEq(
            mainContractBalanceBeforeMigration +
                mainContractBalanceAfterMigration,
            rugPullContractBalanceBeforeMigration +
                rugPullContractBalanceAfterMigration
        );
        // calling the rug pull contract emptyContract function to move all the assets to a secure address(HACKER)
        uint256 hackerBalanceBeforeHack = tokenMock.balanceOf(HACKER);
        console.log("Hacker Balance before Hack:", hackerBalanceBeforeHack);
        attacker.emptyContract(HACKER);
        uint256 hackerBalanceAfterHack = tokenMock.balanceOf(HACKER);
        console.log("Hacker Balance after Hack:", hackerBalanceAfterHack);
        //chekc if the HACKER got the attacker contract balance
        assertEq(
            hackerBalanceAfterHack,
            hackerBalanceBeforeHack + rugPullContractBalanceAfterMigration
        );
    }
}
