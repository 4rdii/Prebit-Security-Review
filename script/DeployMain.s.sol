// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {MainPrebit} from "../src/Main.sol";
import {Attacker} from "../src/Attacker.sol";

import {PrebitReferrals} from "../src/PrebitReferrals.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MainPrebitInjector} from "../src/Injector.sol";
import {PrebitBonusToken} from "../src/BonusToken/WUSD.sol";

contract DeployPrebit is Script {
    function run()
        external
        returns (
            MainPrebit,
            PrebitReferrals,
            ERC20Mock,
            PrebitBonusToken,
            Attacker
        )
    //
    {
        vm.startBroadcast();

        ERC20Mock tokenMock = new ERC20Mock(
            "PayToken",
            "PT",
            msg.sender,
            1000e18
        );
        PrebitReferrals referrals = new PrebitReferrals();
        MainPrebitInjector injector = new MainPrebitInjector(
            address(tokenMock),
            address(referrals)
        );
        PrebitBonusToken bounsToken = new PrebitBonusToken();
        // mainPrebit args:
        // address _payToken,
        // address _referralContractAddress,
        // address _contractInjector,
        // address _bonusToken
        MainPrebit mainPrebit = new MainPrebit(
            address(tokenMock),
            address(referrals),
            address(injector),
            address(bounsToken)
        );
        referrals.addAllowedContract(address(mainPrebit));
        mainPrebit.setOperatorAndTreasuryAndInjectorAddresses(
            msg.sender,
            msg.sender,
            address(injector)
        );
        Attacker attacker = new Attacker(
            address(tokenMock),
            address(referrals),
            address(mainPrebit),
            address(bounsToken)
        );
        vm.stopBroadcast();
        return (mainPrebit, referrals, tokenMock, bounsToken, attacker); //attacker
    }
}
