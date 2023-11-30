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
        require(winner == address(0), "The game has already finished");
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

    function makeChoiceEnc(euint8 encryptedChoice, address player) internal gameNotFinished {
        require(
            player == player1 || player == player2,
            "Player not part of game"
        );

        require(!TFHE.isInitialized(playerChoices[player]), "Player already made a choice");

        euint8 choice = encryptedChoice;
        require(isValidChoice(choice), "Invalid choice");

        playerChoices[player] = choice;

        if (   TFHE.isInitialized(playerChoices[player1])
            && TFHE.isInitialized(playerChoices[player2]) ) {
            // Wrap up game and signal winner
            determineWinner();
        }
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

    function notifyWinner(uint8 winner_id) internal {
        sendMessage(scrollContract, abi.encodePacked(player1, player2, uint256(winner_id)));
    }

    function isValidChoice(euint8 choice) internal view returns (bool) {
        // Use sheilded enum range 1-3 to signify choice
        return TFHE.decrypt(TFHE.gt(choice, TFHE.asEuint8(0))) 
            && TFHE.decrypt(TFHE.lt(choice, TFHE.asEuint8(4)));
    }

    function hasWon(euint8 choice1, euint8 choice2) internal view returns (bool) {
        bool p1rock = TFHE.decrypt(TFHE.eq(choice1, TFHE.asEuint8(1)));
        bool p2scissors = TFHE.decrypt(TFHE.eq(choice2, TFHE.asEuint8(3)));

        if (p1rock && p2scissors) {
            return true;
        }

        bool p1paper = TFHE.decrypt(TFHE.eq(choice1, TFHE.asEuint8(2)));
        bool p2rock = TFHE.decrypt(TFHE.eq(choice2, TFHE.asEuint8(1)));

        if (p1paper && p2rock) {
            return true;
        }

        bool p1scissors = TFHE.decrypt(TFHE.eq(choice1, TFHE.asEuint8(3)));
        bool p2paper = TFHE.decrypt(TFHE.eq(choice2, TFHE.asEuint8(2)));
        
        if (p1scissors && p2paper) {
            return true;
        }

        return false;
    }

    function hasWonOpt(euint8 choice1, euint8 choice2) internal returns (bool) {
        // p1 - p2 + 3 % 3 == 1 means player1 won, else player 2
        ebool p1Won = 
            TFHE.eq(
                TFHE.rem(
                    TFHE.sub(
                        TFHE.add(
                            choice1,
                            TFHE.asEuint8(3)),
                        choice2),
                    3),
                TFHE.asEuint8(1));
        return TFHE.decrypt(p1Won) == true;
    }

    function hackState() public {
        playerChoices[player1] = TFHE.asEuint8(1);
        playerChoices[player2] = TFHE.asEuint8(3);
    }

    function areMovesSame() internal view returns (bool) {
        return TFHE.decrypt(TFHE.eq(playerChoices[player1], playerChoices[player2]));
    }

    function hasPlayer1Won() internal view returns (bool) {
        return hasWonOpt(playerChoices[player1], playerChoices[player2]);
    }

    function determineWinner() internal returns (uint8) {
        if (areMovesSame()) {
            // It's a draw, reset
            playerChoices[player1] = TFHE.NIL8;
            playerChoices[player2] = TFHE.NIL8;
            notifyWinner(0);
            return 0;
        }
        
        if (hasPlayer1Won()) {
            // Player 1 wins
            winner = player1;
            notifyWinner(1);
            return 1;
        }

        // else
        // Player 2 wins
        winner = player2;
        notifyWinner(2);
        return 2;
    }
}
