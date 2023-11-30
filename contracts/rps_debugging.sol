//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import "fhevm/lib/TFHE.sol";

// From : https://docs.hyperlane.xyz/docs/protocol/messaging
// Info https://docs.hyperlane.xyz/docs/build-with-hyperlane/quickstarts/messaging
interface IMailbox {
    function dispatch(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        bytes calldata _messageBody
    ) external returns (bytes32);

    function process(bytes calldata _metadata, bytes calldata _message)
        external;
}

abstract contract ShieldedRPC is EIP712 {
    bytes32 immutable typedDataHash;
    bytes32 immutable typedDataEncHash;

    IMailbox public mailbox;

    struct Message {
        uint256 eventId;
        uint256 param;
    }

    struct MessageEnc {
        bytes eventId;
        bytes param;
    }

    // Signatures for functions that must be implemented in derrived classes
    function handleMessage(uint256 eventId, uint256 param, address context) public virtual;
    function handleEncryptedMessage(bytes calldata encryptedId, bytes calldata encryptedParam, address context) public virtual;

    constructor() EIP712("ShieldedRPC", "1") {
        typedDataHash = keccak256("Message(uint256 eventId,uint256 param,address signedBy)");
        typedDataEncHash = keccak256("Message(bytes eventId,bytes param,address signedBy)");
        // Mailbox on Inco according to
        // https://www.notion.so/Cross-Chain-d9ac0f03d65e48399c6c38ac6e85c3cb
        mailbox = IMailbox(0x4B6ba9EDb2BE6753d95665B2D53766a9c889D9Ce);
    }

    /////////////////////////////////////////////
    // Public functions

    function acceptMessage(uint256 eventId, uint256 param, bytes memory signature) public {
        Message memory message = Message(eventId, param);
        address signer = _verify(message, signature);
        
        handleMessage(eventId, param, signer);
    }

    function acceptEncryptedMessage(bytes calldata encryptedId, bytes calldata encryptedParam, bytes memory signature) public {
        MessageEnc memory message = MessageEnc(encryptedId, encryptedParam);
        address signer = _verifyEnc(message, signature);
        
        handleEncryptedMessage(encryptedId, encryptedParam, signer);
    }

    function sendMessage(address destination, bytes memory data) public {
        uint32 scrollDomain = 534351;
        // TODO pay for messageby sending some native tokens along with the execution
        mailbox.dispatch(
            scrollDomain,
            _addressToBytes32(destination),
            data
        );
    }

    /////////////////////////////////////////////
    // Internal / private functions

    function _verify(Message memory message, bytes memory signature) internal view returns (address) {
        bytes32 digest = _hashTypedData(message);
        return ECDSA.recover(digest, signature);
    }

    function _verifyEnc(MessageEnc memory message, bytes memory signature) internal view returns (address) {
        bytes32 digest = _hashTypedDataEnc(message);
        return ECDSA.recover(digest, signature);
    }

    function _hashTypedData(Message memory message) internal view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    typedDataHash,
                    message.eventId,
                    message.param
                )
            )
        );
    }

    function _hashTypedDataEnc(MessageEnc memory message) internal view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    typedDataEncHash,
                    message.eventId,
                    message.param
                )
            )
        );
    }

    // alignment preserving cast
    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

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

    constructor() {
        // Set up players during deployment
        player1 = 0x7b6aceC5eA36DD5ef5b0639B8C1d0Dab59DdcF03;
        player2 = 0x10c8Fa2185094CbFf433bf22e17Ff123947fA4b7;
        scrollContract = 0x7b6aceC5eA36DD5ef5b0639B8C1d0Dab59DdcF03;
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

    function makeChoiceHack(uint8 choice, address player) public gameNotFinished {
        makeChoiceEnc(TFHE.asEuint8(choice), player);
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
            //determineWinner();
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

    function notifyWinner(uint8 winner_id) public {
        //sendMessage(scrollContract, abi.encodePacked(player1, player2, uint256(winner_id)));
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

    function hackState() public {
        playerChoices[player1] = TFHE.asEuint8(1);
        playerChoices[player2] = TFHE.asEuint8(3);
    }

    function areMovesSame() public view returns (bool) {
        return TFHE.decrypt(TFHE.eq(playerChoices[player1], playerChoices[player2]));
    }

    function hasPlayer1Won() public view returns (bool) {
        return hasWon(playerChoices[player1], playerChoices[player2]);
    }

    function determineWinner() public view returns (uint8) {
        if (areMovesSame()) {
            // It's a draw, reset
            return 0;
        }
        
        if (hasPlayer1Won()) {
            // Player 1 wins
            return 1;
        }

        // else
        // Player 2 wins
        return 2;
    }

    function determineWinner2() public returns (uint8) {
        if (areMovesSame()) {
            // It's a draw, reset
            return 0;
        }
        
        if (hasPlayer1Won()) {
            // Player 1 wins
            return 1;
        }

        // else
        // Player 2 wins
        return 2;
    }

    function determineWinner3() public returns (uint8) {
        if (areMovesSame()) {
            // It's a draw, reset
            //playerChoices[player1] = TFHE.asEuint8(0);
            //playerChoices[player2] = TFHE.asEuint8(0);
            notifyWinner(0);
            //sendMessage(scrollContract, abi.encodePacked(player1, player2, uint256(0)));
            return 0;
        }
        
        if (hasPlayer1Won()) {
            // Player 1 wins
            //winner = player1;
            notifyWinner(1);
            //sendMessage(scrollContract, abi.encodePacked(player1, player2, uint256(1)));
            return 1;
        }

        // else
        // Player 2 wins
        //winner = player2;
        notifyWinner(2);
        //sendMessage(scrollContract, abi.encodePacked(player1, player2, uint256(2)));
        return 2;
    }
}
