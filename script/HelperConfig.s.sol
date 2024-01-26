// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script, console} from "../lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../src/mocks/LinkToken.sol";

contract HelperConfig is Script {
    Config public ActiveConfig;
    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    //    uint256 _entranceFee,
    //         uint256 _interval,
    //         address _vrfCoordinator,
    //         bytes32 _keyHash,
    //         uint64 subId,
    //         uint32 _callBackGasLimit
    struct Config {
        uint256 entranceFee;
        address vrfCoordinator;
        bytes32 keyHash;
        uint64 subId;
        uint32 callBackGasLimit;
        uint256 interval;
        address link;
        uint256 deployerKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            ActiveConfig = sepoliaCOnfig();
        } else if (block.chainid == 31337) {
            ActiveConfig = anvilConfig();
        }
    }

    //    11155111: {
    //     name: "sepolia",
    //     VRFCoordinator: "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
    //     KeyHash: "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c",
    //     callbackGasLimit: "2500000",
    //     entranceFee: ethers.parseEther("0.01"),
    //     interval: "30",
    //     subscriptionId: "5790"
    // },

    function sepoliaCOnfig() private view returns (Config memory) {
        return
            Config({
                entranceFee: 0.002 ether,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subId: 5790,
                callBackGasLimit: 2500000,
                interval: 30,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("PRIVATE_KEY_WITH_ENOUGH_TOKEN")
            });
    }

    function anvilConfig() private returns (Config memory) {
        address vrfCoordinator = ActiveConfig.vrfCoordinator;
        if (vrfCoordinator != address(0)) {
            return ActiveConfig;
        }

        uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9;
        vm.startBroadcast();
        VRFCoordinatorV2Mock mockV3Aggregator = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return (
            Config({
                entranceFee: 0.002 ether,
                vrfCoordinator: address(mockV3Aggregator),
                keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subId: 0,
                callBackGasLimit: 2500000,
                interval: 30,
                link: address(link), // note i dont need this for local host anvil
                deployerKey: DEFAULT_ANVIL_KEY
            })
        );
    }
}
