// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {Raffle} from "../src/Raffle.sol";
import {DeployRaffle} from "../script/DeployRaffle.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vm} from "../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract TestRaffle is Test {
    event RaffleEnter(address indexed players, uint256 indexed amount);
    event IdRequest(uint256 indexed requestId);
    event WinnerPicked(address indexed winner, uint256 indexed amount);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 private constant FUND_USER = 30 ether;
    address USER = makeAddr("USER");

    uint256 entranceFee;
    address vrfCoordinator;
    bytes32 keyHash;
    uint64 subId;
    uint32 callBackGasLimit;
    uint256 interval;
    address link;

    modifier TimePassed() {
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number);
        _;
    }

    function setUp() external {
        vm.deal(USER, FUND_USER);

        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();

        (
            entranceFee,
            vrfCoordinator,
            keyHash,
            subId,
            callBackGasLimit,
            interval,
            link,

        ) = helperConfig.ActiveConfig();
    }

    function testRaffleEntranceFee() external {
        vm.prank(USER);
        uint256 entranceFeeTx = raffle.getEntranceFee();
        assertEq(entranceFeeTx, entranceFee);
    }

    function testRaffleConfirmVrfcoordinator() external {
        address vrfCoordinatorTx = raffle.getVrfCoordinator();
        assertEq(vrfCoordinatorTx, vrfCoordinator);
    }

    //   address _vrfCoordinator,
    //         bytes32 _keyHash,
    //         uint64 subId,
    //         uint32 _callBackGasLimit
    // uint256 _interval,

    function testOtherConstructorStuffs() external {
        uint256 intervalTx = raffle.getInterval();
        bytes32 keyHashTx = raffle.getKeyHash();
        uint64 subIdTx = raffle.getSubId();
        uint32 callBackGasLimitTx = raffle.getCallBackGasLimit();

        assertEq(intervalTx, interval);
        assertEq(keyHashTx, keyHash);
        assert(subIdTx > 0);
        assertEq(callBackGasLimitTx, callBackGasLimit);
    }

    function testEnterRaffleRevertIfNotEnough() external {
        vm.prank(USER);
        vm.expectRevert();
        raffle.enterRaffle();
    }

    function testRaffleDataStructure() external {
        uint256 startingraffleState = raffle.getRaffleState();
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        uint256 amountPlayerFunded = raffle.getAddressToTickets(USER);
        uint256 playersLength = raffle.getPlayersLength();
        assertEq(playersLength, 1);
        assertEq(startingraffleState, 0);
        assertEq(amountPlayerFunded, entranceFee);
    }

    function testRaffleEmitEvent() external {
        vm.expectEmit(true, true, false, false, address(raffle));
        emit RaffleEnter(USER, entranceFee);
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() external {
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("0x0");
        vm.expectRevert();
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheeckUpKeepReturnsFalseIfNotEnoughTimePassed() external {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeep, ) = raffle.checkUpkeep("");
        assertEq(upkeep, false);
    }

    function testCheckupCheeckReturnsFaalseIfTimeHasNotPased() external {
        raffle.enterRaffle{value: entranceFee}();
        (bool upkeep, ) = raffle.checkUpkeep("");
        assert(!upkeep);
    }

    function testRAfflePerformUpKeep() external {
        uint256 balance;
        uint256 players;
        uint256 raffleState;

        //          Raffle__upKeepNotNeeded(
        //     uint256 RaffleState,
        //     uint256 playersLength,
        //     uint256 balance,
        //     uint256 interval
        // );
        vm.expectRevert(
            abi.encodeWithSignature(
                "Raffle__upKeepNotNeeded(uint256,uint256,uint256,uint256)",
                balance,
                players,
                raffleState,
                interval
            )
        );
        raffle.performUpkeep("0x0");
    }

    function testexpectPerformUpKeepToEmitEvent() external {
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number);
        // vm.expectEmit(true, true, true, false, address(raffle));
        // emit IdRequest();
        vm.recordLogs();
        raffle.performUpkeep("0x0");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        uint256 raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(raffleState == 1);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFullfillRandomWordsByOnlyRaffle(
        uint256 _randomRequestId
    ) public TimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            _randomRequestId,
            address(raffle)
        );
    }

    function testFullfillRandomWordsByOnlyRaffleWinnerEmiited()
        external
        TimePassed
        skipFork
    {
        uint160 addtionalEntrance = 5;
        uint160 startingIndex = 1;
        for (uint160 i = startingIndex; i < addtionalEntrance; i++) {
            hoax(address(i), FUND_USER);
            raffle.enterRaffle{value: entranceFee}();
            console.log(address(i));
        }

        vm.recordLogs();
        raffle.performUpkeep("0x0");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 lastTimeStamp = raffle.getTimeStamp();
        address payable getPlayers = raffle.getPlayersWithIndex(0);

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //  s_winner = winner;
        // s_players = new address payable[](0);
        // RaffleState = State.open;
        // s_lastTimeStamp = block.timestamp;
        // uint256 balance = getBalance();

        address winner = raffle.getWinner();
        uint256 playesLength = raffle.getPlayersLength();
        uint256 raffleState = raffle.getRaffleState();
        uint256 newTimeStamp = raffle.getTimeStamp();
        uint256 balance = raffle.getBalance();

        assert(playesLength == 0);
        assert(raffleState == 0);
        assert(newTimeStamp > lastTimeStamp);
        assert(balance == 0);
        assert(winner == address(1));
    }
}
