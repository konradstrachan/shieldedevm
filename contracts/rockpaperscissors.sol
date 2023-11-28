//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "shieldedrpc.sol"

contract RockPaperScissors is ShieldedRPC {
    address public player1;
    address public player2;
    address public winner;
    address public scrollContract;

    mapping(address => euint8) public playerChoices;

    modifier gameNotFinished() {
        require(winner != address(0), "The game has already finished");
        _;
    }

    constructor(address _player1, address _player2, address _scrollContract) {
        // Set up players during deployment
        player1 = _player1;
        player2 = _player2;
        scrollContract = _scrollContract;
        winner = address(0);
    }

    function handleMessage(uint256 eventId, uint256 param, address context) public override {
        require(false, "Only encrypted messages accepted");
    }

    function handleEncryptedMessage(bytes calldata encryptedId, bytes calldata encryptedParam, address context) public override {
        // Simple example only accepts a single command Id:1, reject anything other than this
        require(TFHE.decrypt(TFHE.lt(TFHE.asEuint8(encryptedId), TFHE.asEuint8(1))), "Invalid RPC operation");
        makeChoice(encryptedParam, context);
    }

    function makeChoice(bytes calldata encryptedChoice, address player) internal gameNotFinished {
        require(
            player == player1 || player == player2,
            "Player not part of game"
        );

        require(TFHE.isInitialized(playerChoices[player]), "Player already made a choice");

        euint8 choice = TFHE.asEuint8(encryptedChoice);
        require(isValidChoice(choice), "Invalid choice");

        playerChoices[player] = choice;

        if (   TFHE.isInitialized(playerChoices[player1])
            && TFHE.isInitialized(playerChoices[player2]) ) {
            // Wrap up game and signal winner
            determineWinner();
        }
    }

    function isValidChoice(euint8 choice) internal view returns (bool) {
        // Use sheilded enum range 1-3 to signify choice
        return TFHE.decrypt(TFHE.gt(choice, TFHE.asEuint8(0))) 
            && TFHE.decrypt(TFHE.lt(choice, TFHE.asEuint8(4)));
    }

    function hasWon(euint8 choice1, euint8 choice2) internal view returns (bool) {
        bool p1rock = TFHE.decrypt(TFHE.eq(choice1, TFHE.asEuint8(1)));
        bool p1paper = TFHE.decrypt(TFHE.eq(choice1, TFHE.asEuint8(2)));
        bool p1scissors = TFHE.decrypt(TFHE.eq(choice1, TFHE.asEuint8(3)));

        bool p2rock = TFHE.decrypt(TFHE.eq(choice2, TFHE.asEuint8(1)));
        bool p2paper = TFHE.decrypt(TFHE.eq(choice2, TFHE.asEuint8(2)));
        bool p2scissors = TFHE.decrypt(TFHE.eq(choice2, TFHE.asEuint8(3)));

        return
            (p1rock && p2scissors) ||
            (p1paper && p2rock) ||
            (p1scissors && p2paper);
    }

    function determineWinner() internal {
        if (TFHE.decrypt(TFHE.eq(playerChoices[player1], playerChoices[player2]))) {
            // It's a draw, reset
            playerChoices[player1] = TFHE.asEuint8(0);
            playerChoices[player2] = TFHE.asEuint8(0);

            sendMessage(scrollContract, abi.encodePacked(player1, player2, uint256(0)));
        } else if (hasWon(playerChoices[player1], playerChoices[player2])) {
            // Player 1 wins
            winner = player1;
            sendMessage(scrollContract, abi.encodePacked(player1, player2, uint256(1)));
        } else {
            // Player 2 wins
            winner = player2;
            sendMessage(scrollContract, abi.encodePacked(player1, player2, uint256(2)));
        }
    }
}
