//Prebit - Predict Beta Version 0.1

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
    function injectFunds(
        uint256 _prebitId,
        uint256 _amount,
        uint256 _row
    ) external;

    function currentPreBitId() external view returns (uint256);
}

contract MainPrebitInjector is Ownable {
    using SafeMath for uint256;

    // Interfaces
    IPrebitReferrals public referralContract;
    IERC20 public payToken;

    // Addresses
    address public injectorAddress;
    address public operatorAddress;
    address public treasuryAddress;
    address[] public treasuryWallets;
    uint256[] public treasuryPercentages;

    // Percents
    uint256 public percentTreasury = 15;
    uint256 public percentReferralsLv1 = 10;
    uint256 public percentReferralsLv2 = 5;

    // Constants
    uint256 public constant MAX_CARD_PRICE = 10000000000000000000;

    // Price and variables
    uint256 precardPrice = 2000000000000000000;

    // Rows to Injection
    uint256 percentOfRowsToInjection = 0;
    uint256 public constant MAX_ROWS_TO_INJECTION = 100;

    // Pot Percent
    uint256 public potPercent = 70;

    // Current PreBit and PreCard IDs
    uint256 public currentPreBitId;
    uint256 public currentPreCardId;

    // Time Intervals
    uint256 public intervalToOpenNextPrebit = 0;
    uint256 public intervalToCloseNextPrebit = 1800;
    uint256 public intervalToEndNextPrebit = 3600;

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

    // State Variables
    mapping(uint256 => Prebit) public _prebits;
    mapping(uint256 => Precard) public _precards;
    uint256[6] public rowsRange;
    uint256 public latestPrecardCalculated;
    uint256[6] public pendingInjectionNextPrebit;
    mapping(address => mapping(uint256 => uint256[]))
        public _userPreCardIdsPerPreBitId;

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
    //Events
    event PurchasePrecardEvent(
        address _user,
        uint256 _prebitID,
        uint256[] _prediction,
        uint256 _count,
        uint256 _referralCode
    );
    event PayReferralsEvent(
        address _parent,
        uint256 _prebitID,
        uint256 _payReferralAmount,
        uint256 _totalAmount,
        uint256 _type
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

    constructor(address _payToken, address _referralContractAddress) {
        payToken = IERC20(_payToken);

        referralContract = IPrebitReferrals(_referralContractAddress);
        rowsRange[0] = 0; // Row 1 - 0 Cent
        rowsRange[1] = 25; // Row 2 - 25 Cent
        rowsRange[2] = 50; // Row 3 - 50 Cent
        rowsRange[3] = 100; // Row 4 - 100 Cent
        rowsRange[4] = 500; // Row 5 - 500 Cent
        rowsRange[5] = 1000; // Row 6 - 1000 Cent
    }

    // Purchase a Precard
    function purchasePrecard(
        uint256 _prebitID,
        uint256[] memory _prediction,
        uint256 _referralCode
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
        _paysProcess(totalPayAmount);

        uint256 amountPot = totalPayAmount.mul(potPercent).div(100);
        // Increment the total amount collected for the prebit round
        _prebits[_prebitID].totalEntryAmount += amountPot;
        _prebits[_prebitID].totalTreasuryAmount += totalPayAmount
            .mul(percentTreasury)
            .div(100);

        //Calulate

        _prebits[_prebitID].amountInRows[0] += amountPot.mul(30).div(100);
        _prebits[_prebitID].amountInRows[1] += amountPot.mul(20).div(100);
        _prebits[_prebitID].amountInRows[2] += amountPot.mul(15).div(100);
        _prebits[_prebitID].amountInRows[3] += amountPot.mul(12).div(100);
        _prebits[_prebitID].amountInRows[4] += amountPot.mul(10).div(100);
        _prebits[_prebitID].amountInRows[5] += amountPot.mul(13).div(100);

        //Insert Precard

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

        emit PurchasePrecardEvent(
            msg.sender,
            _prebitID,
            _prediction,
            _prediction.length,
            _referralCode
        );
    }

    function _paysProcess(uint256 _totalPayAmount) private {
        uint256 newAmount = _totalPayAmount;
        address parentAddress = referralContract.getUserParent(msg.sender);
        if (parentAddress != address(0)) {
            newAmount -= _totalPayAmount.mul(percentReferralsLv1).div(100);
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
                1
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
                    2
                );

                newAmount -= _totalPayAmount.mul(percentReferralsLv2).div(100);
            } else {
                _prebits[currentPreBitId].totalTreasuryAmount += _totalPayAmount
                    .mul(percentReferralsLv2)
                    .div(100);
            }
        } else {
            _prebits[currentPreBitId].totalTreasuryAmount += _totalPayAmount
                .mul(percentReferralsLv1 + percentReferralsLv2)
                .div(100);
        }

        payToken.transferFrom(msg.sender, address(this), newAmount);
    }

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

    function startNextPrebitGenesis(
        uint256 _endTime,
        uint256 _openPrecardTime,
        uint256 _closePrecardTime
    ) external onlyOwner {
        require((currentPreBitId == 0), "Not time to start PreBit");

        currentPreBitId++;

        startNext(_endTime, _openPrecardTime, _closePrecardTime);
    }

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
            finalPrice: 0,
            priceSet: false
        });
        _prebits[currentPreBitId].amountInRows[0] = pendingInjectionNextPrebit[
            0
        ];
        _prebits[currentPreBitId].amountInRows[1] = pendingInjectionNextPrebit[
            1
        ];
        _prebits[currentPreBitId].amountInRows[2] = pendingInjectionNextPrebit[
            2
        ];
        _prebits[currentPreBitId].amountInRows[3] = pendingInjectionNextPrebit[
            3
        ];
        _prebits[currentPreBitId].amountInRows[4] = pendingInjectionNextPrebit[
            4
        ];
        _prebits[currentPreBitId].amountInRows[5] = pendingInjectionNextPrebit[
            5
        ];
        pendingInjectionNextPrebit[0] = 0;
        pendingInjectionNextPrebit[1] = 0;
        pendingInjectionNextPrebit[2] = 0;
        pendingInjectionNextPrebit[3] = 0;
        pendingInjectionNextPrebit[4] = 0;
        pendingInjectionNextPrebit[5] = 0;

        emit StartNextPrebitEvent(
            currentPreBitId,
            _endTime,
            _openPrecardTime,
            _closePrecardTime,
            currentPreCardId
        );
    }

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
            }

            latestPrecardCalculated++;
        }

        if (latestPrecardCalculated == currentPreCardId) {
            //Calc  Reward Each card
            if (_prebits[_prebitId].cardsInRows[0] > 0) {
                _prebits[_prebitId].rewardEachCard[0] = (
                    _prebits[_prebitId].amountInRows[0]
                ).div(_prebits[_prebitId].cardsInRows[0]);
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

            //Transfer TreasuryAmount

            _paysTreasury(_prebits[_prebitId].totalTreasuryAmount);

            //
            emit ExecuteDrawFinalPriceEvent(_prebitId, finalPrice);
        }
    }

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
                10
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

    function _calculateRewardsForAllPrecard(
        uint256 _prebitId,
        address _user
    ) public view returns (RewardResult memory) {
        // Retrieve the user number combination from the ticketId

        uint256[] memory userPrecards = getUserPreCardIDs(_user, _prebitId);
        uint256 sumReward;
        bool claimed = false;
        for (uint256 i = 0; i < userPrecards.length; i++) {
            uint256 userPredictPrice = _precards[i].predictPrice;
            claimed = _precards[i].claimed;
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
            return 6; // Means not in any rows
        }
    }

    function isPredictionWithinRange(
        uint256 _myPrice,
        uint256 _rangeCent,
        uint256 _bitcoinPrice
    ) private pure returns (bool) {
        return
            (_myPrice >= _bitcoinPrice.sub(_rangeCent)) &&
            (_myPrice <= _bitcoinPrice.add(_rangeCent));
    }

    function getUserPreCardIDs(
        address _address,
        uint256 _prebit
    ) public view returns (uint256[] memory) {
        return _userPreCardIdsPerPreBitId[_address][_prebit];
    }

    function getPredictPriceWithPrecards(
        uint256[] memory _cards
    ) public view returns (uint256[] memory) {
        uint256[] memory _data = new uint256[](_cards.length);
        for (uint256 i = 0; i < _cards.length; i++) {
            _data[i] = _precards[_cards[i]].predictPrice;
        }
        return _data;
    }

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

    function getCurrentBitPot() public view returns (uint256) {
        return getCountAndAmountCardsInRow(currentPreBitId, 0)[0];
    }

    function getCurrentAmountInAllRows() public view returns (uint256) {
        uint256 sumAmount = 0;
        for (uint256 i = 0; i < 6; i++) {
            sumAmount += getCountAndAmountCardsInRow(currentPreBitId, i)[0];
        }
        return sumAmount;
    }

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

    // Function to get data for multiple Prebits
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

    function setPrecardPrice(uint256 _newPrice) external onlyOwner {
        require(
            _newPrice <= MAX_CARD_PRICE,
            "Price exceeds the maximum allowed"
        );

        precardPrice = _newPrice;

        emit UpdatePrecardPriceEvent(_newPrice);
    }

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
            IPrebit(_newContract).injectFunds(
                IPrebit(_newContract).currentPreBitId(),
                pendingInjectionNextPrebit[i],
                i
            );
            pendingInjectionNextPrebit[i] = 0;
        }

        emit MigrateToNewVersionEvent(_newContract);
    }

    function setPercentOfRowsToInjection(uint256 _percent) external onlyOwner {
        require(_percent <= MAX_ROWS_TO_INJECTION, "Percent exceeds maximum");
        percentOfRowsToInjection = _percent;

        emit SetPercentOfRowsEvent(_percent);
    }

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
}
