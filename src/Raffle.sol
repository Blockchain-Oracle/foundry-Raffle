// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/AutomationCompatible.sol";
error Raffle__NotEnoughEthSent(uint256 requiredAmount);
error Raffle__upKeepNotNeeded(
    uint256 RaffleState,
    uint256 playersLength,
    uint256 balance,
    uint256 interval
);
error Raffle__TransferFailed();
error Raffle__NotOpen();

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    address private immutable i_vrfCoordinator;
    VRFCoordinatorV2Interface vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subId;
    uint16 private constant MINIMUM_CONFIRMATIONS = 3;
    uint32 private immutable i_callBackGasLimit;
    uint32 private constant NUMWORDS = 1;
    address public s_winner;

    mapping(address playerAddress => uint256 amountFunded)
        private s_playerToTickets;

    enum State {
        open,
        calculating
    }

    State private RaffleState;
    event RaffleEnter(address indexed players, uint256 indexed amount);
    event WinnerPicked(address indexed winner, uint256 indexed amount);
    event IdRequest(uint256 indexed requestId);

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 subId,
        uint32 _callBackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = _vrfCoordinator;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        RaffleState = State.open;
        i_keyHash = _keyHash;
        i_subId = subId;
        i_callBackGasLimit = _callBackGasLimit;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent(i_entranceFee);
        }
        if (RaffleState == State.calculating) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        s_playerToTickets[msg.sender] += msg.value;
        emit RaffleEnter(msg.sender, msg.value);
    }

    //is open
    //players >1
    //balance > 0
    //interval >
    //

    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        bool isOpen = (RaffleState == State.open);
        uint256 getlength = getPlayersLength();
        bool playersLength = (getlength > 0);
        uint256 getbalance = getBalance();
        bool balance = (getbalance > 0);
        bool interval = (block.timestamp - s_lastTimeStamp) > i_interval;
        upkeepNeeded = (isOpen && playersLength && balance && interval);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /*performData*/) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            uint256 getlength = getPlayersLength();
            uint256 getbalance = getBalance();
            revert Raffle__upKeepNotNeeded(
                uint256(RaffleState),
                getlength,
                getbalance,
                i_interval
            );
        }

        RaffleState = State.calculating;
        uint256 requestId = vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subId,
            MINIMUM_CONFIRMATIONS,
            i_callBackGasLimit,
            NUMWORDS
        );
        emit IdRequest(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal virtual override {
        uint256 getLength = getPlayersLength();
        uint256 winnerIndex = randomWords[0] % getLength;
        address payable winner = s_players[winnerIndex];
        s_winner = winner;
        s_players = new address payable[](0);
        RaffleState = State.open;
        s_lastTimeStamp = block.timestamp;
        uint256 balance = getBalance();
        (bool sucess, ) = winner.call{value: balance}("");
        if (!sucess) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(winner, balance);
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayersLength() public view returns (uint256) {
        return s_players.length;
    }

    function getRaffleState() public view returns (uint256) {
        return uint256(RaffleState);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getWinner() external view returns (address) {
        return s_winner;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getVrfCoordinator() external view returns (address) {
        return i_vrfCoordinator;
    }

    function getKeyHash() external view returns (bytes32) {
        return i_keyHash;
    }

    function getSubId() external view returns (uint64) {
        return i_subId;
    }

    function getCallBackGasLimit() external view returns (uint32) {
        return i_callBackGasLimit;
    }

    function getAddressToTickets(
        address playerAddress
    ) external view returns (uint256) {
        return s_playerToTickets[playerAddress];
    }

    function getTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getPlayersWithIndex(
        uint256 _index
    ) public view returns (address payable) {
        return s_players[_index];
    }
}
