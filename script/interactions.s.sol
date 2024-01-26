// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Script, console} from "../lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {LinkToken} from "../src/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function run() external returns (uint64) {
        return createSubScriptionUsingConfig();
    }

    function createSubScriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, address vrfCoordinator, , , , , , uint256 deployerKey) = helperConfig
            .ActiveConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address _vrfCoordiator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("createSubscription on chainId", block.chainid);
        VRFCoordinatorV2Mock vrfCoordinator = VRFCoordinatorV2Mock(
            _vrfCoordiator
        );
        vm.startBroadcast(deployerKey);
        uint64 subId = vrfCoordinator.createSubscription();
        vm.stopBroadcast();

        console.log("your subId is", subId);
        console.log("pls update subscriptionId in HelperConfig.s.sol");
        return subId;
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 1 ether;

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.ActiveConfig();

        fundSubscription(vrfCoordinator, subId, link, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("fundSubscription on chainId", block.chainid);
        console.log("subId", subId);
        console.log("using vrfcoordinator", vrfCoordinator);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() external {
        address mostRecentDeploy = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.ActiveConfig();

        addConsumer(subId, vrfCoordinator, mostRecentDeploy, deployerKey);
    }

    function addConsumer(
        uint64 subId,
        address vrfCoordinator,
        address raffle,
        uint256 deployerKey
    ) public {
        console.log("addConsumer on chainId", block.chainid);
        console.log("subId", subId);
        console.log("using vrfcoordinator", vrfCoordinator);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }
}
