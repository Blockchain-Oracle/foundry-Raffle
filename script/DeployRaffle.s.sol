// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {Script, console} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        //   uint256 entranceFee;
        // address vrfCoordinator;
        // bytes32 keyHash;
        // uint64 subId;
        // uint32 callBackGasLimit;
        // uint256 interval;
        (
            uint256 entranceFee,
            address vrfCoordinator,
            bytes32 keyHash,
            uint64 subId,
            uint32 callBackGasLimit,
            uint256 interval,
            address link,
            uint256 deployerKey
        ) = helperConfig.ActiveConfig();

        if (subId == 0) {
            console.log("no subId found, creating one");
            CreateSubscription createSubscription = new CreateSubscription();
            subId = createSubscription.createSubscription(
                vrfCoordinator,
                deployerKey
            );

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast(deployerKey);
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            keyHash,
            subId,
            callBackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            subId,
            vrfCoordinator,
            address(raffle),
            deployerKey
        );
        return (raffle, helperConfig);
    }
}
