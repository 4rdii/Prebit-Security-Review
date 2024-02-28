//Refferal Contract Prebit - Beta Version 0.1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Ownable.sol";

contract PrebitReferrals is Ownable {
    ///
    address[] public allowedContracts;

    modifier onlyAllowedContract() {
        require(
            isContractAllowed(msg.sender),
            "Caller is not an allowed contract"
        );
        _;
    }

    function addAllowedContract(address _contractAddress) public onlyOwner {
        allowedContracts.push(_contractAddress);
    }

    function removeAllowedContract(address _contractAddress) public onlyOwner {
        for (uint256 i = 0; i < allowedContracts.length; i++) {
            if (allowedContracts[i] == _contractAddress) {
                // Remove the contract address from the array
                allowedContracts[i] = allowedContracts[
                    allowedContracts.length - 1
                ];
                allowedContracts.pop();
                break;
            }
        }
    }

    function isContractAllowed(
        address _contractAddress
    ) public view returns (bool) {
        for (uint256 i = 0; i < allowedContracts.length; i++) {
            if (allowedContracts[i] == _contractAddress) {
                return true;
            }
        }
        return false;
    }

    //Patents ///////////////

    struct Referrals {
        uint256 code;
        address parent;
        address tparent;
        bool valid;
    }

    mapping(address => Referrals) public userReferralCode; // Mapping to track user's referral codes
    mapping(uint256 => address) public referralCodeToAddress; // Mapping to track used referral codes
    event ReferralCodeGenerated(address indexed user, uint256 referralCode);

    function generateReferralCode(uint256 _parentCode) public {
        if (!userReferralCode[msg.sender].valid) {
            uint256 referralCode = uint256(
                keccak256(abi.encodePacked(msg.sender, block.timestamp))
            ) % 1000000;
            while (referralCodeToAddress[referralCode] != address(0)) {
                referralCode = (referralCode + 1) % 1000000;
            }

            address parentAddress;
            address tparentAddress;
            if (
                _parentCode > 0 &&
                referralCodeToAddress[_parentCode] != address(0)
            ) {
                parentAddress = referralCodeToAddress[_parentCode];

                if (userReferralCode[parentAddress].parent != address(0)) {
                    tparentAddress = userReferralCode[parentAddress].parent;
                } else {
                    tparentAddress = address(0);
                }
            } else {
                parentAddress = address(0);
                tparentAddress = address(0);
            }

            userReferralCode[msg.sender] = Referrals(
                referralCode,
                parentAddress,
                tparentAddress,
                true
            );
            referralCodeToAddress[referralCode] = msg.sender;

            emit ReferralCodeGenerated(msg.sender, referralCode);
        }
    }

    function generateReferralCodeWithContract(
        uint256 _parentCode,
        address _user
    ) public onlyAllowedContract {
        if (!userReferralCode[_user].valid) {
            uint256 referralCode = uint256(
                keccak256(abi.encodePacked(_user, block.timestamp))
            ) % 1000000;
            while (referralCodeToAddress[referralCode] != address(0)) {
                referralCode = (referralCode + 1) % 1000000;
            }

            address parentAddress;
            address tparentAddress;
            if (
                _parentCode > 0 &&
                referralCodeToAddress[_parentCode] != address(0)
            ) {
                parentAddress = referralCodeToAddress[_parentCode];

                if (userReferralCode[parentAddress].parent != address(0)) {
                    tparentAddress = userReferralCode[parentAddress].parent;
                } else {
                    tparentAddress = address(0);
                }
            } else {
                parentAddress = address(0);
                tparentAddress = address(0);
            }

            userReferralCode[_user] = Referrals(
                referralCode,
                parentAddress,
                tparentAddress,
                true
            );
            referralCodeToAddress[referralCode] = _user;

            emit ReferralCodeGenerated(_user, referralCode);
        }
    }

    function userReferralCodeCheck(address _user) public view returns (bool) {
        if (userReferralCode[_user].valid) {
            return true;
        } else {
            return false;
        }
    }

    function userReferralCodeToAddress(
        uint256 _code
    ) public view returns (address) {
        return referralCodeToAddress[_code];
    }

    function getUserReferralCode(address user) public view returns (uint256) {
        return userReferralCode[user].code;
    }

    function getUserTparent(address _user) public view returns (address) {
        return userReferralCode[_user].tparent;
    }

    function getUserParent(address _user) public view returns (address) {
        return userReferralCode[_user].parent;
    }
}
