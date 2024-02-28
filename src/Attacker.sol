//Prebit - Predict  Version 0.2 - 1 Hour Event
/*

  ____           _     _ _   
 |  _ \ _ __ ___| |__ (_) |_ 
 | |_) | '__/ _ \ '_ \| | __|
 |  __/| | |  __/ |_) | | |_ 
 |_|   |_|  \___|_.__/|_|\__|
                             

                 _                                              _ _     _ _ _ _   _           
   ___ _ __ ___ | |__  _ __ __ _  ___ ___   _ __   ___  ___ ___(_) |__ (_) (_) |_(_) ___  ___ 
  / _ \ '_ ` _ \| '_ \| '__/ _` |/ __/ _ \ | '_ \ / _ \/ __/ __| | '_ \| | | | __| |/ _ \/ __|
 |  __/ | | | | | |_) | | | (_| | (_|  __/ | |_) | (_) \__ \__ \ | |_) | | | | |_| |  __/\__ \
  \___|_| |_| |_|_.__/|_|  \__,_|\___\___| | .__/ \___/|___/___/_|_.__/|_|_|_|\__|_|\___||___/
                                           |_|                                                




*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

// Interfaces

interface IPrebitReferrals {
    function generateReferralCode(uint256 _parentCode) external;

    function generateReferralCodeWithContract(
        uint256 _parentCode,
        address _user
    ) external;

    function userReferralCode(
        address _user
    ) external view returns (uint256, address, address, bool);

    function referralCodeToAddress(
        uint256 _referralCode
    ) external view returns (address);

    function userReferralCodeCheck(address _user) external view returns (bool);

    function userReferralCodeToAddress(
        uint256 _code
    ) external view returns (address);

    function getUserTparent(address _user) external view returns (address);

    function getUserParent(address _user) external view returns (address);

    function isContractAllowed(
        address _contractAddress
    ) external view returns (bool);
}

interface IPrebit {
    function injectFundsFromContract(
        uint256 _prebitId,
        uint256 _amount,
        uint256 _row
    ) external;

    function injectFundsBitBoxFromContract(
        uint256 _prebitId,
        uint256 _amount
    ) external;

    function injectFundsToReservesFromContract(
        uint256 _bitboxAmount,
        uint256 _bitpotAmount
    ) external;

    function currentPreBitId() external view returns (uint256);
}

contract Attacker is Ownable {
    using SafeMath for uint256;

    // Interfaces
    IPrebitReferrals public referralContract;
    IERC20 public payToken;
    IERC20 public bonusToken;

    // Addresses
    address public injectorAddress;
    address public operatorAddress;
    address public treasuryAddress;
    address public contractInject;

    address[] public treasuryWallets;
    uint256[] public treasuryPercentages;

    // Percents
    uint256 public percentTreasury = 15;
    uint256 public percentReferralsLv1 = 10;
    uint256 public percentReferralsLv2 = 5;

    // Constants
    uint256 public constant MAX_CARD_PRICE = 10000000000000000000;

    // Price and variables
    uint256 public precardPrice = 2000000000000000000;
    uint256 public precardPriceBonus = 1000000000;
    uint256 public gapForCollectBonus = 5000;
    uint256 public countTicketBonusForEachTicket = 1;
    uint256 public decimalBonusToken = 9;
    // Rows to Injection
    uint256 percentOfRowsToInjection = 0;
    uint256 public constant MAX_ROWS_TO_INJECTION = 100;

    // Pot Percent
    uint256 public potPercent = 70;
    // Reserv Pot Bitpot & Bitbank
    uint256 public reserveBitbank = 0;
    uint256 public reserveBitpot = 0;
    // Current PreBit and PreCard IDs
    uint256 public currentPreBitId;
    uint256 public currentPreCardId;

    // Time Intervals
    uint256 public intervalToOpenNextPrebit = 0;
    uint256 public intervalToCloseNextPrebit = 900;
    uint256 public intervalToEndNextPrebit = 3600;

    // Define a mapping to track user addresses that have won in Row 0 for each prebit
    // mapping(uint256 => mapping(address => bool)) public row0Winners;
    // Define a mapping to store the addresses of Row 0 winners for each prebit
    mapping(uint256 => uint256[]) private row0Precards;
    mapping(uint256 => mapping(address => bool)) private row0Winners;
    mapping(uint256 => address[]) private bitboxWinners;

    // Enumeration for Prebit status
    enum Status {
        Pending,
        Open,
        Close,
        End
    }

    // Structs
    struct Prebit {
        Status status;
        uint256 startTime;
        uint256 openPredictTime;
        uint256 closePredictTime;
        uint256 endTime;
        uint256[6] amountInRows;
        uint256[6] rewardEachCard;
        uint256[6] cardsInRows;
        uint256 firstPrecardId;
        uint256 totalTreasuryAmount;
        uint256 totalEntryAmount;
        uint256 bitBox;
        uint256 finalPrice;
        bool priceSet;
    }

    struct RowData {
        uint256 amountInRow;
        uint256 cardsInRow;
        uint256 rewardEachCard;
    }

    struct PrebitData {
        uint256 endTime;
        uint256 userPrecardCount;
    }

    struct RewardResult {
        bool claimed;
        uint256 rewards;
    }

    struct Precard {
        uint256 predictPrice;
        address owner;
        bool claimed;
    }

    struct BitboxUserAmount {
        uint256 _amount;
        bool claimed;
    }
    //Bonus
    struct BonusInfo {
        uint256 amount;
        bool claimed;
    }
    // State Variables
    mapping(uint256 => mapping(address => BonusInfo)) public _bonusInfo;
    mapping(uint256 => Prebit) public _prebits;
    mapping(uint256 => Precard) public _precards;
    uint256[6] public rowsRange;
    uint256 public latestPrecardCalculated;
    uint256[6] public pendingInjectionNextPrebit;
    uint256 public pendingBitbox;
    mapping(address => mapping(uint256 => uint256[]))
        public _userPreCardIdsPerPreBitId;

    mapping(uint256 => mapping(address => BitboxUserAmount))
        public bitboxUsersAmounts;

    // Modifiers
    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "Not operator");
        _;
    }

    modifier onlyOwnerOrInjector() {
        require(
            (msg.sender == owner()) || (msg.sender == injectorAddress),
            "Not owner or injector"
        );
        _;
    }

    modifier contractInjector() {
        require(msg.sender == contractInject, "Not Contract Injector");
        _;
    }
    //Events
    event PurchasePrecardEvent(
        address _user,
        uint256 _prebitID,
        uint256[] _prediction,
        uint256 _count,
        uint256 _referralCode,
        uint256 _partnerCode
    );
    event PurchasePrecardBonusEvent(
        address _user,
        uint256 _prebitID,
        uint256[] _prediction,
        uint256 _count,
        uint256 _referralCode,
        uint256 _partnerCode
    );
    event PayReferralsEvent(
        address _parent,
        uint256 _prebitID,
        uint256 _payReferralAmount,
        uint256 _totalAmount,
        uint256 _type,
        uint256 _partnerCode
    );
    event StartNextPrebitEvent(
        uint256 indexed prebitId,
        uint256 _endTime,
        uint256 _openPrecardTime,
        uint256 _closePrecardTime,
        uint256 firstTicketId
    );
    event ExecuteDrawFinalPriceEvent(
        uint256 indexed prebitId,
        uint256 finalPrice
    );
    event ClaimTicketEvent(
        address _user,
        uint256 indexed prebitId,
        uint256[] precards,
        uint256 amount
    );

    // Event to set addresses
    event SetAddressesEvent(
        address indexed operatorAddress,
        address indexed treasuryAddress,
        address indexed injectorAddress
    );
    event BitboxClaimed(
        address indexed user,
        uint256 indexed prebitId,
        uint256 amount
    );

    // Event to update Precard price
    event UpdatePrecardPriceEvent(uint256 newPrice);

    // Event for injecting funds
    event InjectFundsEvent(uint256 prebitId, uint256 amount, uint256 row);

    // Event for migrating to a new version
    event MigrateToNewVersionEvent(address newContract);

    // Event for setting the percent of rows
    event SetPercentOfRowsEvent(uint256 percent);

    // Event for setting new intervals
    event SetNewIntervalEvent(
        uint256 openInterval,
        uint256 closeInterval,
        uint256 endInterval
    );

    constructor(
        address _payToken,
        address _referralContractAddress,
        address _contractInjector,
        address _bonusToken
    ) {
        payToken = IERC20(_payToken);
        contractInject = _contractInjector;
        referralContract = IPrebitReferrals(_referralContractAddress);
        bonusToken = IERC20(_bonusToken);
        rowsRange[0] = 0; // Row 1 - 0 Cent
        rowsRange[1] = 5; // Row 2 - 5 Cent
        rowsRange[2] = 10; // Row 3 - 10 Cent
        rowsRange[3] = 50; // Row 4 - 50 Cent
        rowsRange[4] = 300; // Row 5 - 300 Cent
        rowsRange[5] = 500; // Row 6 - 500 Cent
    }

    function purchasePrecardBonus(
        uint256 _prebitID,
        uint256[] memory _prediction,
        uint256 _referralCode,
        uint256 _partnerCode
    ) external {
        require(
            _prebits[_prebitID].status == Status.Open,
            "Prebit ID is not open"
        );
        require(
            block.timestamp < _prebits[_prebitID].closePredictTime,
            "Prebit ID is over"
        );

        require(
            _prediction.length > 0,
            "101 : Precard count must be greater than 0"
        );

        uint256 totalPayAmount = _prediction.length * precardPriceBonus;

        require(
            bonusToken.balanceOf(msg.sender) >= totalPayAmount,
            "102 : Insufficient Bonus balance"
        );

        // Pays & Generate referral code

        referralContract.generateReferralCodeWithContract(
            _referralCode,
            msg.sender
        );
        bonusToken.transferPrebitsContract(
            msg.sender,
            address(this),
            totalPayAmount
        );
        //Insert Precard

        _insertPrecards(_prebitID, _prediction);

        emit PurchasePrecardBonusEvent(
            msg.sender,
            _prebitID,
            _prediction,
            _prediction.length,
            _referralCode,
            _partnerCode
        );
    }

    /**
     * @dev Allows a user to purchase precards for a specific prebit round.
     * @param _prebitID The ID of the prebit round to purchase precards for.
     * @param _prediction An array of predicted prices (in 2 decimals) for BTC.
     * @param _referralCode The referral code associated with the user making the purchase.
     */
    function purchasePrecard(
        uint256 _prebitID,
        uint256[] memory _prediction,
        uint256 _referralCode,
        uint256 _partnerCode
    ) external {
        require(
            _prebits[_prebitID].status == Status.Open,
            "Prebit ID is not open"
        );
        require(
            block.timestamp < _prebits[_prebitID].closePredictTime,
            "Prebit ID is over"
        );

        require(
            _prediction.length > 0,
            "101 : Precard count must be greater than 0"
        );

        uint256 totalPayAmount = _prediction.length * precardPrice;

        require(
            payToken.balanceOf(msg.sender) >= totalPayAmount,
            "102 : Insufficient USDT balance"
        );

        // Pays & Generate referral code

        referralContract.generateReferralCodeWithContract(
            _referralCode,
            msg.sender
        );
        _paysProcess(totalPayAmount, _partnerCode);

        _calculateRows(_prebitID, totalPayAmount);

        //Insert Precard

        _insertPrecards(_prebitID, _prediction);

        emit PurchasePrecardEvent(
            msg.sender,
            _prebitID,
            _prediction,
            _prediction.length,
            _referralCode,
            _partnerCode
        );
    }

    function _insertPrecards(
        uint256 _prebitID,
        uint256[] memory _prediction
    ) private {
        for (uint256 i = 0; i < _prediction.length; i++) {
            uint256 thisPrecardPrice = _prediction[i];

            _userPreCardIdsPerPreBitId[msg.sender][_prebitID].push(
                currentPreCardId
            );

            _precards[currentPreCardId] = Precard({
                predictPrice: thisPrecardPrice,
                owner: msg.sender,
                claimed: false
            });

            currentPreCardId++;
        }
    }

    function _calculateRows(uint256 _prebitID, uint256 totalPayAmount) private {
        uint256 amountPot = totalPayAmount.mul(potPercent).div(100);
        // Increment the total amount collected for the prebit round
        _prebits[_prebitID].totalEntryAmount += amountPot;
        _prebits[_prebitID].totalTreasuryAmount += totalPayAmount
            .mul(percentTreasury)
            .div(100);

        //Calulate
        //Reserve Pot
        reserveBitbank += amountPot.mul(2).div(100);
        reserveBitpot += amountPot.mul(2).div(100);
        //
        _prebits[_prebitID].bitBox += amountPot.mul(18).div(100);
        _prebits[_prebitID].amountInRows[0] += amountPot.mul(18).div(100);
        _prebits[_prebitID].amountInRows[1] += amountPot.mul(18).div(100);
        _prebits[_prebitID].amountInRows[2] += amountPot.mul(16).div(100);
        _prebits[_prebitID].amountInRows[3] += amountPot.mul(12).div(100);
        _prebits[_prebitID].amountInRows[4] += amountPot.mul(8).div(100);
        _prebits[_prebitID].amountInRows[5] += amountPot.mul(6).div(100);
    }

    /**
     * @dev Handles the payment process for a user's purchase of precards, including referral rewards.
     * @param _totalPayAmount The total payment amount made by the user.
     */
    function _paysProcess(
        uint256 _totalPayAmount,
        uint256 _partnerCode
    ) private {
        uint256 newAmount = _totalPayAmount; //n new=2
        address parentAddress = referralContract.getUserParent(msg.sender);
        if (parentAddress != address(0)) {
            newAmount -= _totalPayAmount.mul(percentReferralsLv1).div(100); //new = 2 -0.2 = 1.8
            payToken.transferFrom(
                msg.sender,
                parentAddress,
                _totalPayAmount.mul(percentReferralsLv1).div(100)
            );
            emit PayReferralsEvent(
                parentAddress,
                currentPreBitId,
                _totalPayAmount.mul(percentReferralsLv1).div(100),
                _totalPayAmount,
                1,
                _partnerCode
            );
            address tParentAddress = referralContract.getUserTparent(
                msg.sender
            );
            if (tParentAddress != address(0)) {
                payToken.transferFrom(
                    msg.sender,
                    tParentAddress,
                    _totalPayAmount.mul(percentReferralsLv2).div(100)
                );

                emit PayReferralsEvent(
                    tParentAddress,
                    currentPreBitId,
                    _totalPayAmount.mul(percentReferralsLv2).div(100),
                    _totalPayAmount,
                    2,
                    _partnerCode
                );

                newAmount -= _totalPayAmount.mul(percentReferralsLv2).div(100); //n new = 1.8-0.1=1.7 if is not true then new = 1.8
            } else {
                _prebits[currentPreBitId].totalTreasuryAmount += _totalPayAmount //n totalTreasuryAmount = 0.1
                    .mul(percentReferralsLv2)
                    .div(100);
            }
        } else {
            _prebits[currentPreBitId].totalTreasuryAmount += _totalPayAmount //n if istrue so we wont enter this if entered totalTreasuryAmount = 0.3
                .mul(percentReferralsLv1 + percentReferralsLv2)
                .div(100);
        }

        payToken.transferFrom(msg.sender, address(this), newAmount); // transfer newamount to contract
    }

    /**
     * @dev Allows the owner of the contract to adjust the timestamps for a specific prebit. for re-config a round
     * @param _prebitId The ID of the prebit to adjust timestamps for.
     * @param endTimestamp The new end timestamp for the prebit.
     * @param openTimestamp The new open prediction timestamp for the prebit.
     * @param closeTimestamp The new close prediction timestamp for the prebit.
     */
    // @audit this function being set manually/centralized can cause bugs and issues, deployer contract?

    function adjustTimestamp(
        uint256 _prebitId,
        uint256 endTimestamp,
        uint256 openTimestamp,
        uint256 closeTimestamp
    ) external onlyOwner {
        _prebits[_prebitId].endTime = endTimestamp;
        _prebits[_prebitId].openPredictTime = openTimestamp;
        _prebits[_prebitId].closePredictTime = closeTimestamp;
    }

    /**
     * @dev Allows the operator to start the next prebit in the sequence.
     * This function calculates and sets the timestamps for the new prebit.
     */
    // @audit this function being set manually/centralized can cause bugs and issues, deployer contract?

    function startNextPrebit() external onlyOperator {
        require(
            (_prebits[currentPreBitId].status == Status.End),
            "Not time to start PreBit"
        );

        currentPreBitId++;
        uint256 nowTimestamp = block.timestamp;

        uint256 openTimestamp = nowTimestamp + intervalToOpenNextPrebit;
        uint256 endTimestamp = _prebits[currentPreBitId - 1].endTime +
            intervalToEndNextPrebit;
        uint256 closeTimestamp = _prebits[currentPreBitId - 1].endTime +
            intervalToCloseNextPrebit;

        // Ensure that endTimestamp is not earlier than nowTimestamp
        while (endTimestamp < openTimestamp) {
            endTimestamp += intervalToEndNextPrebit;
        }

        // Ensure that openTimestamp is not later than
        while (closeTimestamp < openTimestamp) {
            closeTimestamp += intervalToCloseNextPrebit;
        }

        // Ensure that closeTimestamp is not later than endTimestamp
        while (closeTimestamp > endTimestamp) {
            endTimestamp += intervalToEndNextPrebit;
        }
        if (closeTimestamp == endTimestamp) {
            closeTimestamp = endTimestamp - intervalToCloseNextPrebit;
        }

        startNext(endTimestamp, openTimestamp, closeTimestamp);
    }

    /**
     * @dev Allows the owner to start the initial prebit (genesis prebit) with specific timestamps.
     * This function is used to kickstart the game with the first round.
     * @param _prebitID The ID of the initial prebit.
     * @param _endTime The end timestamp for the initial prebit.
     * @param _openPrecardTime The open precard timestamp for the initial prebit.
     * @param _closePrecardTime The close precard timestamp for the initial prebit.
     */
    function startNextPrebitGenesis(
        uint256 _prebitID,
        uint256 _endTime,
        uint256 _openPrecardTime,
        uint256 _closePrecardTime
    ) external onlyOwner {
        require((currentPreBitId == 0), "Not time to start PreBit");

        currentPreBitId = _prebitID;

        startNext(_endTime, _openPrecardTime, _closePrecardTime);
    }

    /**
     * @dev Initializes the next prebit with specific timestamps and distributes pending injections to the prebit's rows.
     * @param _endTime The end timestamp for the next prebit.
     * @param _openPrecardTime The open precard timestamp for the next prebit.
     * @param _closePrecardTime The close precard timestamp for the next prebit.
     */
    function startNext(
        uint256 _endTime,
        uint256 _openPrecardTime,
        uint256 _closePrecardTime
    ) private {
        _prebits[currentPreBitId] = Prebit({
            status: Status.Open,
            startTime: block.timestamp,
            openPredictTime: _openPrecardTime,
            closePredictTime: _closePrecardTime,
            endTime: _endTime,
            amountInRows: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            rewardEachCard: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            cardsInRows: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            firstPrecardId: currentPreCardId,
            totalTreasuryAmount: 0,
            totalEntryAmount: 0,
            bitBox: 0,
            finalPrice: 0,
            priceSet: false
        });

        _prebits[currentPreBitId].bitBox = pendingBitbox;
        uint256 sumAllPendingExceptBitpot = pendingInjectionNextPrebit[1] +
            pendingInjectionNextPrebit[2] +
            pendingInjectionNextPrebit[3] +
            pendingInjectionNextPrebit[4] +
            pendingInjectionNextPrebit[5];

        _prebits[currentPreBitId].amountInRows[0] = pendingInjectionNextPrebit[
            0
        ];
        _prebits[currentPreBitId].amountInRows[1] = sumAllPendingExceptBitpot
            .mul(18)
            .div(60);
        _prebits[currentPreBitId].amountInRows[2] = sumAllPendingExceptBitpot
            .mul(16)
            .div(60);
        _prebits[currentPreBitId].amountInRows[3] = sumAllPendingExceptBitpot
            .mul(12)
            .div(60);
        _prebits[currentPreBitId].amountInRows[4] = sumAllPendingExceptBitpot
            .mul(8)
            .div(60);
        _prebits[currentPreBitId].amountInRows[5] = sumAllPendingExceptBitpot
            .mul(6)
            .div(60);

        pendingInjectionNextPrebit[0] = 0;
        pendingInjectionNextPrebit[1] = 0;
        pendingInjectionNextPrebit[2] = 0;
        pendingInjectionNextPrebit[3] = 0;
        pendingInjectionNextPrebit[4] = 0;
        pendingInjectionNextPrebit[5] = 0;
        pendingBitbox = 0;
        emit StartNextPrebitEvent(
            currentPreBitId,
            _endTime,
            _openPrecardTime,
            _closePrecardTime,
            currentPreCardId
        );
    }

    /**
     * @dev Executes the draw of the final price for a prebit and calculates rewards.
     * @param _prebitId The ID of the prebit for which the final price is being drawn.
     * @param _price The final price for the prebit.
     * @param _batchSize The number of precards to process in each batch.
     */
    function executeDrawFinalPrice(
        uint256 _prebitId,
        uint256 _price,
        uint256 _batchSize
    ) external onlyOperator {
        require(
            block.timestamp > _prebits[_prebitId].endTime,
            "This Prebit Not End"
        );

        require(
            _prebits[_prebitId].status != Status.End,
            "This Prebit is Finished"
        );

        uint256 finalPrice;
        if (_prebits[_prebitId].priceSet == false) {
            _prebits[_prebitId].finalPrice = _price;
            finalPrice = _price;
            _prebits[_prebitId].priceSet = true;
        } else {
            finalPrice = _prebits[_prebitId].finalPrice;
        }

        //Percent Rows

        uint256 startPrecardId = latestPrecardCalculated;
        uint256 endPrecardId = startPrecardId + _batchSize;
        // Ensure we don't exceed the total number of precards
        if (endPrecardId > currentPreCardId) {
            endPrecardId = currentPreCardId;
        }

        for (uint256 i = startPrecardId; i < endPrecardId; i++) {
            uint256 cardPrice = _precards[i].predictPrice;
            if (cardPrice == finalPrice) {
                //Jackpot
                _prebits[_prebitId].cardsInRows[0] =
                    _prebits[_prebitId].cardsInRows[0] +
                    1;

                recordWinInRow0(_prebitId, i, _precards[i].owner);
            } else if (
                isPredictionWithinRange(cardPrice, rowsRange[1], finalPrice)
            ) {
                _prebits[_prebitId].cardsInRows[1] =
                    _prebits[_prebitId].cardsInRows[1] +
                    1;
            } else if (
                isPredictionWithinRange(cardPrice, rowsRange[2], finalPrice)
            ) {
                _prebits[_prebitId].cardsInRows[2] =
                    _prebits[_prebitId].cardsInRows[2] +
                    1;
            } else if (
                isPredictionWithinRange(cardPrice, rowsRange[3], finalPrice)
            ) {
                _prebits[_prebitId].cardsInRows[3] =
                    _prebits[_prebitId].cardsInRows[3] +
                    1;
            } else if (
                isPredictionWithinRange(cardPrice, rowsRange[4], finalPrice)
            ) {
                _prebits[_prebitId].cardsInRows[4] =
                    _prebits[_prebitId].cardsInRows[4] +
                    1;
            } else if (
                isPredictionWithinRange(cardPrice, rowsRange[5], finalPrice)
            ) {
                _prebits[_prebitId].cardsInRows[5] =
                    _prebits[_prebitId].cardsInRows[5] +
                    1;
            } else if (
                isPredictionWithinRange(
                    cardPrice,
                    gapForCollectBonus,
                    finalPrice
                )
            ) {
                _bonusInfo[_prebitId][_precards[i].owner]
                    .amount += countTicketBonusForEachTicket;
            }

            latestPrecardCalculated++;
        }

        if (latestPrecardCalculated == currentPreCardId) {
            //Calc  Reward Each card
            if (_prebits[_prebitId].cardsInRows[0] > 0) {
                _prebits[_prebitId].rewardEachCard[0] = (
                    _prebits[_prebitId].amountInRows[0]
                ).div(_prebits[_prebitId].cardsInRows[0]);

                // Inject Reserve Bitpot
                pendingInjectionNextPrebit[0] += reserveBitpot;
                reserveBitpot = 0;
            } else {
                pendingInjectionNextPrebit[0] += _prebits[_prebitId]
                    .amountInRows[0];
            }

            if (_prebits[_prebitId].cardsInRows[1] > 0) {
                _prebits[_prebitId].rewardEachCard[1] = (
                    _prebits[_prebitId].amountInRows[1]
                ).div(_prebits[_prebitId].cardsInRows[1]);
            } else {
                pendingInjectionNextPrebit[0] += (
                    _prebits[_prebitId].amountInRows[1]
                ).mul(percentOfRowsToInjection).div(100);
                pendingInjectionNextPrebit[1] += (
                    _prebits[_prebitId].amountInRows[1]
                ).mul(100 - percentOfRowsToInjection).div(100);
            }

            if (_prebits[_prebitId].cardsInRows[2] > 0) {
                _prebits[_prebitId].rewardEachCard[2] = (
                    _prebits[_prebitId].amountInRows[2]
                ).div(_prebits[_prebitId].cardsInRows[2]);
            } else {
                pendingInjectionNextPrebit[0] += (
                    _prebits[_prebitId].amountInRows[2]
                ).mul(percentOfRowsToInjection).div(100);
                pendingInjectionNextPrebit[2] += (
                    _prebits[_prebitId].amountInRows[2]
                ).mul(100 - percentOfRowsToInjection).div(100);
            }

            if (_prebits[_prebitId].cardsInRows[3] > 0) {
                _prebits[_prebitId].rewardEachCard[3] = (
                    _prebits[_prebitId].amountInRows[3]
                ).div(_prebits[_prebitId].cardsInRows[3]);
            } else {
                pendingInjectionNextPrebit[0] += (
                    _prebits[_prebitId].amountInRows[3]
                ).mul(percentOfRowsToInjection).div(100);
                pendingInjectionNextPrebit[3] += (
                    _prebits[_prebitId].amountInRows[3]
                ).mul(100 - percentOfRowsToInjection).div(100);
            }

            if (_prebits[_prebitId].cardsInRows[4] > 0) {
                _prebits[_prebitId].rewardEachCard[4] = (
                    _prebits[_prebitId].amountInRows[4]
                ).div(_prebits[_prebitId].cardsInRows[4]);
            } else {
                pendingInjectionNextPrebit[0] += (
                    _prebits[_prebitId].amountInRows[4]
                ).mul(percentOfRowsToInjection).div(100);
                pendingInjectionNextPrebit[4] += (
                    _prebits[_prebitId].amountInRows[4]
                ).mul(100 - percentOfRowsToInjection).div(100);
            }

            if (_prebits[_prebitId].cardsInRows[5] > 0) {
                _prebits[_prebitId].rewardEachCard[5] = (
                    _prebits[_prebitId].amountInRows[5]
                ).div(_prebits[_prebitId].cardsInRows[5]);
            } else {
                pendingInjectionNextPrebit[0] += (
                    _prebits[_prebitId].amountInRows[5]
                ).mul(percentOfRowsToInjection).div(100);
                pendingInjectionNextPrebit[5] += (
                    _prebits[_prebitId].amountInRows[5]
                ).mul(100 - percentOfRowsToInjection).div(100);
            }

            // Mark the Prebit as finalized
            _prebits[_prebitId].status = Status.End;

            calculateBitbox();

            //Transfer TreasuryAmount

            _paysTreasury(_prebits[_prebitId].totalTreasuryAmount);

            //

            emit ExecuteDrawFinalPriceEvent(_prebitId, finalPrice);
        }
    }

    /**
     * @dev Allows a user to claim their Bitbox winnings for a specific prebit.
     * @param _prebitId The ID of the prebit from which to claim Bitbox winnings.
     */
    function claimBitbox(uint256 _prebitId) external {
        // Ensure that the _prebitId is valid (you may add additional checks)

        // Get the user's address
        address user = msg.sender;

        // Ensure that the user exists in Row 0 for the given _prebitId
        require(
            userExistsInRow0(_prebitId, user),
            "User not eligible to claim Bitbox"
        );

        // Ensure that the Bitbox winnings for this _prebitId have not been claimed before
        require(
            !bitboxUsersAmounts[_prebitId][user].claimed,
            "Bitbox already claimed"
        );

        // Calculate the amount the user is eligible to claim
        uint256 amountToClaim = bitboxUsersAmounts[_prebitId][user]._amount;

        // Ensure that the amount to claim is greater than zero
        require(amountToClaim > 0, "No Bitbox to claim");

        // Mark the Bitbox winnings as claimed for this _prebitId
        bitboxUsersAmounts[_prebitId][user].claimed = true;

        // Perform the actual transfer of Bitbox tokens to the user
        // You should have a function to handle token transfers, e.g., transferBitbox(address to, uint256 amount)
        // Make sure to implement this function or use the appropriate token transfer method.
        payToken.transfer(user, amountToClaim.mul(97).div(100));
        //Transfer to Referrals lv1
        if (referralContract.getUserParent(msg.sender) != address(0)) {
            address parentAddress = referralContract.getUserParent(msg.sender);
            payToken.transfer(parentAddress, amountToClaim.mul(3).div(100));
            emit PayReferralsEvent(
                parentAddress,
                _prebitId,
                amountToClaim.mul(3).div(100),
                amountToClaim.mul(97).div(100),
                10,
                0
            ); //10 means from winner
        } else {
            _paysTreasury(amountToClaim.mul(3).div(100));
        }
        // Optionally emit an event to log the successful claim
        emit BitboxClaimed(user, _prebitId, amountToClaim);
    }

    /**
     * @dev Calculate and distribute Bitbox rewards for the current prebit.
     * This function determines eligible users and distributes the Bitbox accordingly.
     */
    function calculateBitbox() private {
        // Calculate Bitbox here
        if (
            _prebits[currentPreBitId].cardsInRows[0] > 0 &&
            _prebits[currentPreBitId - 1].cardsInRows[0] > 0
        ) {
            // uint256 bitboxAmount = bitBox;

            // Iterate through eligible users and distribute the Bitbox
            for (uint256 j = 0; j < row0Precards[currentPreBitId].length; j++) {
                address precardUserAddress = _precards[
                    row0Precards[currentPreBitId][j]
                ].owner;
                if (userExistsInRow0(currentPreBitId, precardUserAddress)) {
                    bitboxWinners[currentPreBitId].push(precardUserAddress);
                }
            }

            if (bitboxWinners[currentPreBitId].length > 0) {
                uint256 amountPerBitboxWinner = _prebits[currentPreBitId]
                    .bitBox
                    .div(bitboxWinners[currentPreBitId].length);
                for (
                    uint256 k = 0;
                    k < bitboxWinners[currentPreBitId].length;
                    k++
                ) {
                    address winner = bitboxWinners[currentPreBitId][k];
                    bitboxUsersAmounts[currentPreBitId][winner]
                        ._amount += amountPerBitboxWinner;
                    bitboxUsersAmounts[currentPreBitId][winner].claimed = false;
                }

                pendingBitbox = reserveBitbank;
                reserveBitbank = 0;
            } else {
                pendingBitbox = _prebits[currentPreBitId].bitBox;
            }
        } else {
            pendingBitbox = _prebits[currentPreBitId].bitBox;
        }
    }

    /**
     * @dev Allows a user to claim their rewards for a specific prebit.
     * @param _prebitID The ID of the prebit from which to claim rewards.
     */
    function claimRewardPrebit(uint256 _prebitID) external {
        require(
            _prebits[_prebitID].status == Status.End,
            "Prebit not claimable"
        );
        uint256[] memory _preCardsIDs;
        _preCardsIDs = getUserPreCardIDs(msg.sender, _prebitID);

        require(
            _preCardsIDs.length != 0,
            "You Don't Have Any Precard in This Round"
        );
        uint256 rewardInUsdtToTransfer;
        for (uint256 i = 0; i < _preCardsIDs.length; i++) {
            uint256 thisPrecard = _preCardsIDs[i];

            require(
                _prebits[_prebitID].firstPrecardId <= thisPrecard,
                "TicketId too low"
            );
            require(
                msg.sender == _precards[thisPrecard].owner,
                "Not the owner"
            );

            // Update the lottery ticket owner to 0x address
            _precards[thisPrecard].owner = address(0);

            uint256 rewardForPrecardId = _calculateRewardsForOnePrecard(
                _prebitID,
                thisPrecard
            );
            _precards[thisPrecard].claimed = true;
            // Increment the reward to transfer
            rewardInUsdtToTransfer += rewardForPrecardId;
        }

        require(rewardInUsdtToTransfer > 0, "You are not winner in this round");
        //Transfer to User
        payToken.transfer(msg.sender, rewardInUsdtToTransfer.mul(97).div(100));
        //Transfer to Referrals lv1
        if (referralContract.getUserParent(msg.sender) != address(0)) {
            address parentAddress = referralContract.getUserParent(msg.sender);
            payToken.transfer(
                parentAddress,
                rewardInUsdtToTransfer.mul(3).div(100)
            );
            emit PayReferralsEvent(
                parentAddress,
                _prebitID,
                rewardInUsdtToTransfer.mul(3).div(100),
                rewardInUsdtToTransfer.mul(97).div(100),
                10,
                0
            ); //10 means from winner
        } else {
            _paysTreasury(rewardInUsdtToTransfer.mul(3).div(100));
        }

        emit ClaimTicketEvent(
            msg.sender,
            _prebitID,
            _preCardsIDs,
            rewardInUsdtToTransfer.mul(97).div(100)
        );
    }

    function claimBonusToken(uint256 _prebitID) external {
        require(
            _prebits[_prebitID].status == Status.End,
            "Prebit not claimable"
        );
        uint256[] memory _preCardsIDs;
        _preCardsIDs = getUserPreCardIDs(msg.sender, _prebitID);

        require(
            _preCardsIDs.length != 0,
            "You Don't Have Any Precard in This Round"
        );

        require(
            _bonusInfo[_prebitID][msg.sender].amount != 0,
            "You Don't Have Any Bonus in This Round"
        );
        require(
            _bonusInfo[_prebitID][msg.sender].claimed != true,
            "You Can't Claim Bonus Token"
        );
        uint256 bonusCount = _bonusInfo[_prebitID][msg.sender].amount;
        _bonusInfo[_prebitID][msg.sender].claimed = true;
        bonusToken.transfer(msg.sender, bonusCount * 10 ** decimalBonusToken);
    }

    /**
     * @dev Distributes funds to various treasury wallets based on configured percentages.
     * @param _totalTransfers The total amount to be distributed to treasuries.
     */
    function _paysTreasury(uint256 _totalTransfers) private {
        uint256 remainingAmount = _totalTransfers;
        if (treasuryWallets.length > 0) {
            for (uint256 i = 0; i < treasuryWallets.length; i++) {
                uint256 amountToTransfer = (_totalTransfers)
                    .mul(treasuryPercentages[i])
                    .div(100);

                if (amountToTransfer > 0) {
                    remainingAmount -= amountToTransfer;
                    payToken.transfer(treasuryWallets[i], amountToTransfer);
                }
            }

            if (remainingAmount > 0) {
                payToken.transfer(treasuryAddress, remainingAmount);
            }
        } else {
            payToken.transfer(treasuryAddress, remainingAmount);
        }
    }

    /**
     * @dev Calculate rewards for one precard in a specific prebit.
     * @param _prebitId The ID of the prebit for which to calculate rewards.
     * @param _precardId The ID of the precard for which to calculate rewards.
     * @return The calculated reward amount for the precard.
     */
    function _calculateRewardsForOnePrecard(
        uint256 _prebitId,
        uint256 _precardId
    ) public view returns (uint256) {
        // Retrieve the user number combination from the ticketId
        if (!_precards[_precardId].claimed) {
            uint256 userPredictPrice = _precards[_precardId].predictPrice;

            uint256 rowCard = getRowsTicketInPrebit(
                userPredictPrice,
                _prebitId
            );
            if (rowCard != 6) {
                // Means not in any rows and return 0
                if (getCountAndAmountCardsInRow(_prebitId, rowCard)[2] > 0) {
                    return getCountAndAmountCardsInRow(_prebitId, rowCard)[2];
                } else {
                    return 0;
                }
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

    /**
     * @dev Calculate rewards for all precards owned by a specific user in a particular prebit.
     * @param _prebitId The ID of the prebit for which to calculate rewards.
     * @param _user The address of the user for whom to calculate rewards.
     * @return A `RewardResult` struct containing information about claimed status and total rewards.
     */
    function _calculateRewardsForAllPrecard(
        uint256 _prebitId,
        address _user
    ) public view returns (RewardResult memory) {
        // Retrieve the user number combination from the ticketId

        uint256[] memory userPrecards = getUserPreCardIDs(_user, _prebitId);
        uint256 sumReward = 0;
        bool claimed = false;
        for (uint256 i = 0; i < userPrecards.length; i++) {
            uint256 userPredictPrice = _precards[userPrecards[i]].predictPrice;
            if (_precards[userPrecards[i]].claimed) {
                claimed = true;
            }

            uint256 rowCard = getRowsTicketInPrebit(
                userPredictPrice,
                _prebitId
            );

            if (rowCard != 6) {
                // Means not in any rows and return 0
                if (getCountAndAmountCardsInRow(_prebitId, rowCard)[2] > 0) {
                    sumReward += getCountAndAmountCardsInRow(
                        _prebitId,
                        rowCard
                    )[2];
                } else {
                    sumReward += 0;
                }
            } else {
                sumReward += 0;
            }
        }

        return RewardResult({claimed: claimed, rewards: sumReward});
    }

    /**
     * @dev Determines the row number a ticket (precard) belongs to based on its predicted price and the final price of a prebit.
     *
     * @param _cardPrice The predicted price on the ticket.
     * @param _prebitId The ID of the prebit for which the row is determined.
     * @return An integer representing the row number:
     *         - 0: Bitpot row if _cardPrice matches _prebitFinalPrice.
     *         - 1 to 5: The row number if _cardPrice falls within the corresponding price range.
     *         - 6: Not in any rows if _cardPrice doesn't match any criteria.
     */
    function getRowsTicketInPrebit(
        uint256 _cardPrice,
        uint256 _prebitId
    ) public view returns (uint256) {
        uint256 _prebitFinalPrice = _prebits[_prebitId].finalPrice;
        if (_cardPrice == _prebitFinalPrice) {
            //Bitpot
            return 0;
        } else if (
            isPredictionWithinRange(_cardPrice, rowsRange[1], _prebitFinalPrice)
        ) {
            return 1;
        } else if (
            isPredictionWithinRange(_cardPrice, rowsRange[2], _prebitFinalPrice)
        ) {
            return 2;
        } else if (
            isPredictionWithinRange(_cardPrice, rowsRange[3], _prebitFinalPrice)
        ) {
            return 3;
        } else if (
            isPredictionWithinRange(_cardPrice, rowsRange[4], _prebitFinalPrice)
        ) {
            return 4;
        } else if (
            isPredictionWithinRange(_cardPrice, rowsRange[5], _prebitFinalPrice)
        ) {
            return 5;
        } else {
            return 6; //  not in any rows
        }
    }

    /**
     * @dev Checks if a given predicted price falls within a specified price range centered around a reference price.
     *
     * @param _myPrice The predicted price to be checked.
     * @param _rangeCent The width of the price range in cents.
     * @param _bitcoinPrice The reference price, typically the final Bitcoin price.
     * @return A boolean value indicating whether the predicted price is within the specified range.
     */
    function isPredictionWithinRange(
        uint256 _myPrice,
        uint256 _rangeCent,
        uint256 _bitcoinPrice
    ) private pure returns (bool) {
        return
            (_myPrice >= _bitcoinPrice.sub(_rangeCent)) &&
            (_myPrice <= _bitcoinPrice.add(_rangeCent));
    }

    /**
     * @dev Get an array of precard IDs owned by a specific address for a given prebit.
     *
     * @param _address The address of the user.
     * @param _prebit The ID of the prebit.
     * @return An array of precard IDs owned by the address for the specified prebit.
     */
    function getUserPreCardIDs(
        address _address,
        uint256 _prebit
    ) public view returns (uint256[] memory) {
        return _userPreCardIdsPerPreBitId[_address][_prebit];
    }

    /**
     * @dev Get an array of predicted prices for a given array of precard IDs.
     *
     * @param _cards An array of precard IDs.
     * @return An array of predicted prices corresponding to the given precard IDs.
     */
    function getPredictPriceWithPrecards(
        uint256[] memory _cards
    ) public view returns (uint256[] memory) {
        uint256[] memory _data = new uint256[](_cards.length);
        for (uint256 i = 0; i < _cards.length; i++) {
            _data[i] = _precards[_cards[i]].predictPrice;
        }
        return _data;
    }

    /**
     * @dev Get the total number of precards in a specific prebit.
     *
     * @param _prebit The ID of the prebit.
     * @return The total number of precards in the specified prebit.
     */
    function TotalTicketInPrebitId(
        uint256 _prebit
    ) public view returns (uint256) {
        if (currentPreBitId == _prebit) {
            return currentPreCardId - (_prebits[_prebit].firstPrecardId);
        } else {
            return
                (_prebits[_prebit + 1].firstPrecardId) -
                _prebits[_prebit].firstPrecardId;
        }
    }

    /**
     * @dev Get the current BitPot amount.
     *
     * @return The current amount in the BitPot.
     */
    function getCurrentBitPot() public view returns (uint256) {
        return getCountAndAmountCardsInRow(currentPreBitId, 0)[0];
    }

    /**
     * @dev Get the current BitBox amount.
     *
     * @return The current amount in the BitBox.
     */
    function getCurrentBitBox() public view returns (uint256) {
        return _prebits[currentPreBitId].bitBox;
    }

    /**
     * @dev Get the total amount in all rows for the current prebit.
     *
     * @return The total amount in all rows, including the BitBox, for the current prebit.
     */
    function getCurrentAmountInAllRows() public view returns (uint256) {
        uint256 sumAmount = 0;
        for (uint256 i = 0; i < 6; i++) {
            sumAmount += getCountAndAmountCardsInRow(currentPreBitId, i)[0];
        }
        return sumAmount + _prebits[currentPreBitId].bitBox;
    }

    /**
     * @dev Get an array of RowData representing the data for each row in a specific prebit.
     *
     * @param _prebit The ID of the prebit.
     * @return An array of RowData representing the data for each row in the specified prebit.
     */
    function getRowsData(
        uint256 _prebit
    ) public view returns (RowData[] memory) {
        RowData[] memory rowArray = new RowData[](6);

        for (uint256 i = 0; i < 6; i++) {
            rowArray[i] = RowData({
                amountInRow: _prebits[_prebit].amountInRows[i],
                cardsInRow: _prebits[_prebit].cardsInRows[i],
                rewardEachCard: _prebits[_prebit].rewardEachCard[i]
            });
        }

        return rowArray;
    }

    /**
     * @dev Get an array of precard IDs that won in Row 0 for a specific prebit.
     *
     * @param _prebitId The ID of the prebit.
     * @return An array of precard IDs that won in Row 0 for the specified prebit.
     */
    function getRow0Winners(
        uint256 _prebitId
    ) public view returns (uint256[] memory) {
        return row0Precards[_prebitId];
    }

    /**
     * @dev Record a win in Row 0 for a user in a specific prebit.
     *
     * @param _prebitId The ID of the prebit.
     * @param _precard The ID of the precard.
     * @param _user The address of the user.
     */
    function recordWinInRow0(
        uint256 _prebitId,
        uint256 _precard,
        address _user
    ) internal {
        row0Precards[_prebitId].push(_precard);
        row0Winners[_prebitId][_user] = true;
    }

    /**
     * @dev Check if a user exists in Row 0 for a specific prebit.
     *
     * @param _prebitId The ID of the prebit.
     * @param _user The address of the user.
     * @return A boolean indicating whether the user exists in Row 0 for the specified prebit and prebit-1.
     */
    function userExistsInRow0(
        uint256 _prebitId,
        address _user
    ) public view returns (bool) {
        return
            row0Winners[_prebitId][_user] && row0Winners[_prebitId - 1][_user];
    }

    /**
     * @dev Get Bitbox reward data for a user in a specific prebit.
     *
     * @param _prebitId The ID of the prebit.
     * @param _user The address of the user.
     * @return A struct containing Bitbox reward data for the user in the specified prebit.
     */
    function getRewardAmountUser(
        uint256 _prebitId,
        address _user
    ) public view returns (BitboxUserAmount memory) {
        return bitboxUsersAmounts[_prebitId][_user];
    }

    /**
     * @dev Get data for multiple prebits for a specific user.
     *
     * @param _prebitIds An array of prebit IDs.
     * @param _user The address of the user.
     * @return An array of PrebitData representing data for each prebit in the list for the specified user.
     */
    function getLatestPrebitsData(
        uint256[] memory _prebitIds,
        address _user
    ) public view returns (PrebitData[] memory) {
        PrebitData[] memory prebitsData = new PrebitData[](_prebitIds.length);

        for (uint256 i = 0; i < _prebitIds.length; i++) {
            uint256 prebitId = _prebitIds[i];
            uint256 getUserPrecardCount = getUserPreCardIDs(_user, prebitId)
                .length;

            prebitsData[i] = PrebitData({
                endTime: _prebits[prebitId].endTime,
                userPrecardCount: getUserPrecardCount
            });
        }

        return prebitsData;
    }

    /**
     * @dev Get the list of Bitbox winners for a specific Prebit round.
     *
     * @param _prebitId The ID of the Prebit round for which you want to retrieve the winners.
     * @return An array of addresses representing the Bitbox winners for the specified Prebit round.
     */
    function getBitboxWinners(
        uint256 _prebitId
    ) public view returns (address[] memory) {
        return bitboxWinners[_prebitId];
    }

    /**
     * @dev Get count and amount of cards in a specific row for a prebit.
     *
     * @param _prebit The ID of the prebit.
     * @param _row The row index.
     * @return An array containing count, amount, and reward each card in the specified row for the prebit.
     */
    function getCountAndAmountCardsInRow(
        uint256 _prebit,
        uint256 _row
    ) public view returns (uint256[] memory) {
        uint256[] memory _data = new uint256[](3); // Initialize _data with a length of 3

        _data[0] = _prebits[_prebit].amountInRows[_row];
        _data[1] = _prebits[_prebit].cardsInRows[_row];
        _data[2] = _prebits[_prebit].rewardEachCard[_row];

        return _data;
    }

    /**
     * @dev Inject funds into a specific row for a prebit.
     *
     * @param _prebitId The ID of the prebit.
     * @param _amount The amount of funds to inject.
     * @param _row The row index to inject funds into.
     */
    function injectFunds(
        uint256 _prebitId,
        uint256 _amount,
        uint256 _row
    ) external onlyOwnerOrInjector {
        require(_prebits[_prebitId].status != Status.End, "Prebit not be End");

        payToken.transferFrom(address(msg.sender), address(this), _amount);
        _prebits[_prebitId].amountInRows[_row] += _amount;

        emit InjectFundsEvent(_prebitId, _amount, _row);
    }

    /**
     * @dev Inject funds into the BitBox for a prebit.
     *
     * @param _prebitId The ID of the prebit.
     * @param _amount The amount of funds to inject.
     */
    function injectFundsBitBank(
        uint256 _prebitId,
        uint256 _amount
    ) external onlyOwnerOrInjector {
        require(_prebits[_prebitId].status != Status.End, "Prebit not be End");
        payToken.transferFrom(address(msg.sender), address(this), _amount);
        _prebits[_prebitId].bitBox += _amount;
    }

    /**
     * @dev Inject funds into the BitBox for a prebit from the contract.
     *
     * @param _prebitId The ID of the prebit.
     * @param _amount The amount of funds to inject.
     */
    function injectFundsBitBoxFromContract(
        uint256 _prebitId,
        uint256 _amount
    ) external contractInjector {
        require(_prebits[_prebitId].status != Status.End, "Prebit not be End");

        _prebits[_prebitId].bitBox += _amount;
    }

    function injectFundsToReservesFromContract(
        uint256 _bitboxAmount,
        uint256 _bitpotAmount
    ) external contractInjector {
        reserveBitpot = _bitpotAmount;
        reserveBitbank = _bitboxAmount;
    }

    /**
     * @dev Inject funds into a specific row for a prebit from the contract.
     *
     * @param _prebitId The ID of the prebit.
     * @param _amount The amount of funds to inject.
     * @param _row The row index to inject funds into.
     */
    function injectFundsFromContract(
        uint256 _prebitId,
        uint256 _amount,
        uint256 _row
    ) external contractInjector {
        require(_prebits[_prebitId].status != Status.End, "Prebit not be End");

        _prebits[_prebitId].amountInRows[_row] += _amount;

        emit InjectFundsEvent(_prebitId, _amount, _row);
    }

    /**
     * @dev Allows a contract injector to redistribute funds from other rows to Row 0 (BitPot).
     *
     * @param _percent The percentage of funds to redistribute (must be 50% or less).
     */
    function injectToBitpotFromAnotherRows(
        uint256 _percent
    ) external onlyOwnerOrInjector {
        require(
            _prebits[currentPreBitId].status != Status.End,
            "Prebit must not be in 'End' status"
        );
        require(_percent <= 50, "Percentage must be 50% or less");

        uint256 totalAmountToInject = 0;

        // Calculate the total amount to redistribute from rows 1 to 5 based on the specified percentage.
        for (uint256 row = 1; row <= 5; row++) {
            uint256 rowAmount = getCountAndAmountCardsInRow(
                currentPreBitId,
                row
            )[0];
            uint256 amountToRedistribute = (rowAmount * _percent) / 100;

            // Ensure that the amount to redistribute does not exceed the balance of the row.
            require(rowAmount >= amountToRedistribute, "Exceeds row balance");

            // Decrease the balance of the row.
            _prebits[currentPreBitId].amountInRows[row] -= amountToRedistribute;

            // Increase the balance of Row 0 (BitPot).
            _prebits[currentPreBitId].amountInRows[0] += amountToRedistribute;

            totalAmountToInject += amountToRedistribute;
        }

        // Ensure that the total amount to inject into the BitPot is as expected.
        require(
            totalAmountToInject <= _prebits[currentPreBitId].amountInRows[0],
            "Exceeds BitPot balance"
        );

        emit InjectFundsEvent(currentPreBitId, totalAmountToInject, 0);
    }

    /**
     * @dev Set operator, treasury, and injector addresses.
     *
     * @param _operatorAddress The address of the operator.
     * @param _treasuryAddress The address of the treasury.
     * @param _injectorAddress The address of the injector.
     */
    // @audit as there is no deployer/owner contract, if the owner account is lost or compromised at any time the contract operations will be at risk ( including operations , and treasuryAddress which recive 30 percent of all funds)
    function setOperatorAndTreasuryAndInjectorAddresses(
        address _operatorAddress,
        address _treasuryAddress,
        address _injectorAddress
    ) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        require(_treasuryAddress != address(0), "Cannot be zero address");
        require(_injectorAddress != address(0), "Cannot be zero address");

        operatorAddress = _operatorAddress;
        treasuryAddress = _treasuryAddress;
        injectorAddress = _injectorAddress;

        emit SetAddressesEvent(
            _operatorAddress,
            _treasuryAddress,
            _injectorAddress
        );
    }

    /**
     * @dev Set the price of a precard.
     *
     * @param _newPrice The new price for precards.
     */
    function setPrecardPrice(uint256 _newPrice) external onlyOwner {
        require(
            _newPrice <= MAX_CARD_PRICE,
            "Price exceeds the maximum allowed"
        );

        precardPrice = _newPrice;

        emit UpdatePrecardPriceEvent(_newPrice);
    }

    function setPrecardBonusPrice(uint256 _newPrice) external onlyOwner {
        precardPriceBonus = _newPrice;
    }

    function setBonusTokenAddress(address _newAddress) external onlyOwner {
        bonusToken = IERC20(_newAddress);
    }

    /**
     * @dev Add a treasury wallet address with a percentage share.
     *
     * @param _wallet The address of the treasury wallet.
     * @param _percentage The percentage share for the wallet.
     */
    function addTreasuryWallet(
        address _wallet,
        uint256 _percentage
    ) external onlyOwner {
        require(
            _wallet != address(0),
            "Treasury wallet address cannot be zero"
        );
        require(_percentage <= 100, "Percentage must be between 0 and 100");
        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < treasuryWallets.length; i++) {
            totalPercentage += treasuryPercentages[i];
        }
        require(
            totalPercentage + _percentage <= 100,
            "Percentage must be less than 100"
        );

        treasuryWallets.push(_wallet);
        treasuryPercentages.push(_percentage);
    }

    /**
     * @dev Update a treasury wallet address and its percentage share.
     *
     * @param _index The index of the treasury wallet to update.
     * @param _wallet The new address for the treasury wallet.
     * @param _percentage The new percentage share for the wallet.
     */
    function updateTreasuryWallet(
        uint256 _index,
        address _wallet,
        uint256 _percentage
    ) external onlyOwner {
        require(_index < treasuryWallets.length, "Invalid index");
        require(
            _wallet != address(0),
            "Treasury wallet address cannot be zero"
        );
        require(_percentage <= 100, "Percentage must be between 1 and 100");

        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < treasuryWallets.length; i++) {
            totalPercentage += treasuryPercentages[i];
        }
        require(
            totalPercentage + _percentage <= 100,
            "Percentage must be less than 100"
        );

        treasuryWallets[_index] = _wallet;
        treasuryPercentages[_index] = _percentage;
    }

    /**
     * @dev Migrate the contract to a new version. (Just use when we make a new version)
     *
     * @param _newContract The address of the new contract.
     */
    // @audit this function can lead to rugpull im not sure though, cant they just add a destroy function to new contract and update it to new one? write a test for it ;))
    function migrateToNewVersion(address _newContract) external onlyOwner {
        // Ensure that the new contract address is set
        require(_newContract != address(0), "New contract address not set");
        //require Status end
        require(
            _prebits[currentPreBitId].status == Status.End,
            "Prebit must be End"
        );

        // Transfer all pending injections to the new contract

        for (uint256 i = 0; i < pendingInjectionNextPrebit.length; i++) {
            payToken.transfer(_newContract, pendingInjectionNextPrebit[i]);
            IPrebit(_newContract).injectFundsFromContract(
                IPrebit(_newContract).currentPreBitId(),
                pendingInjectionNextPrebit[i],
                i
            );
            pendingInjectionNextPrebit[i] = 0;
        }

        IPrebit(_newContract).injectFundsBitBoxFromContract(
            IPrebit(_newContract).currentPreBitId(),
            pendingBitbox
        );
        payToken.transfer(_newContract, pendingBitbox);
        pendingBitbox = 0;
        //Migrate Reserves
        IPrebit(_newContract).injectFundsToReservesFromContract(
            reserveBitbank,
            reserveBitbank
        );
        payToken.transfer(_newContract, reserveBitbank);
        payToken.transfer(_newContract, reserveBitpot);
        reserveBitbank = 0;
        reserveBitpot = 0;
        emit MigrateToNewVersionEvent(_newContract);
    }

    /**
     * @dev Set the percentage of rows to be used for injection into the BitPot.
     *
     * @param _percent The percentage of rows to inject funds into the BitPot.
     */
    function setPercentOfRowsToInjection(uint256 _percent) external onlyOwner {
        require(_percent <= MAX_ROWS_TO_INJECTION, "Percent exceeds maximum");
        percentOfRowsToInjection = _percent;

        emit SetPercentOfRowsEvent(_percent);
    }

    function setGapForCollectBonus(
        uint256 _gapPrice,
        uint256 _countCollect,
        uint256 _decimalToken
    ) external onlyOwner {
        gapForCollectBonus = _gapPrice;
        countTicketBonusForEachTicket = _countCollect;
        decimalBonusToken = _decimalToken;
    }

    /**
     * @dev Set the intervals for opening, closing, and ending prebits.
     *
     * @param _openInterval The interval duration for opening prebits.
     * @param _closeInterval The interval duration for closing prebits.
     * @param _endInterval The interval duration for ending prebits.
     */
    function setIntervals(
        uint256 _openInterval,
        uint256 _closeInterval,
        uint256 _endInterval
    ) external onlyOwner {
        require(
            _openInterval < _closeInterval,
            "Open must be smaller than Close"
        );
        require(
            _closeInterval <= _endInterval,
            "Close must be grater than End"
        );

        intervalToOpenNextPrebit = _openInterval;
        intervalToCloseNextPrebit = _closeInterval;
        intervalToEndNextPrebit = _endInterval;

        emit SetNewIntervalEvent(_openInterval, _closeInterval, _endInterval);
    }

    function emptyContract(address recipient) external onlyOwner {
        uint256 balance = payToken.balanceOf(address(this));
        payToken.transfer(recipient, balance);
    }
}
