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
    IMailbox public mailbox;

    struct Message {
        uint256 eventId;
        uint256 param;
    }

    function handleMessage(uint256 eventId, uint256 param, address context) public virtual;

    constructor() EIP712("ShieldedRPC", "1") {
        typedDataHash = keccak256("Message(uint256 eventId,uint256 param,address signedBy)");
        // Mailbox on Inco according to
        // https://www.notion.so/Cross-Chain-d9ac0f03d65e48399c6c38ac6e85c3cb
        mailbox = IMailbox(0x4B6ba9EDb2BE6753d95665B2D53766a9c889D9Ce);
    }

    function acceptMessage(uint256 eventId, uint256 param, bytes memory signature) public {
        Message memory message = Message(eventId, param);
        address signer = _verify(message, signature);
        
        handleMessage(eventId, param, signer);
    }

    function _verify(Message memory message, bytes memory signature) internal view returns (address) {
        bytes32 digest = _hashTypedData(message);
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

    // alignment preserving cast
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function sendMessage(address destination, bytes memory data) public {
        uint32 scrollDomain = 534351;
        mailbox.dispatch(
            scrollDomain,
            addressToBytes32(destination),
            data
        );
    }
}

contract ShuffledCards is ShieldedRPC {
    // Each card is represented by an 8-bit number.
    // The most significant 6 bits represent the card value,
    // and the least significant 2 bits represent the suit.
    euint8[52] private deck;
    uint8 private revealed;

    constructor() {
        revealed = 0;

        // initialise deck
        uint8 index = 0;
        for (uint8 suit = 0; suit < 4; suit++) {
            for (uint8 value = 0; value < 13; value++) {
                uint8 card = (suit << 6) | value;
                deck[index] = TFHE.asEuint8(card);
                index++;
            }
        }

        // Shuffle naively
        for (index = 0; index < 52; index++) {
            euint8 i = getCardIndex();
            euint8 j = getCardIndex();
            
            // Note this requires decrypting.. must be a better way
            euint8 temp = deck[i];
            deck[i] = deck[j];
            deck[j] = temp;
        }
    }

    function getCardIndex() private returns (euint8) {
        euint8 val = TFHE.randEuint8();
        
        // Requires decrypt, fix this
        while(TFHE.lt(val, 52) != true) {
            val = TFHE.randEuint8();
        }
        
        return val;
    }

    function handleMessage(uint256 eventId, uint256 param, address context) public override {
        uint8 card = TFHE.decrypt(deck[revealed++]);
        sendMessage(context, abi.encodePacked(card));
    }
}

contract SecretToken is ShieldedRPC {
    mapping(address => euint32) internal balances;

    constructor() { }

    function handleMessage(uint256 eventId, uint256 param, address context) public override {
        if (eventId == 1) {
            // Add the balance
            balances[context] = TFHE.add(balances[context], TFHE.asEuint32(param));

            // return result to invoker
            uint32 result = TFHE.decrypt(balances[context]);
            sendMessage(context, abi.encodePacked(result));
        }

        if (eventId == 2) {
            // Subtract from the balance
            balances[context] = TFHE.sub(balances[context], TFHE.asEuint32(param));

            // return result to invoker
            uint32 result = TFHE.decrypt(balances[context]);
            sendMessage(context, abi.encodePacked(result));
        }
    }
}