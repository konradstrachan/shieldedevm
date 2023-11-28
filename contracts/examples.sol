//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "shieldedrpc.sol"

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

    function handleEncryptedMessage(bytes calldata encryptedId, bytes calldata encryptedParam, address context) public override {
        require(false, "Only non-encrypted messages accepted");
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

    function handleEncryptedMessage(bytes calldata encryptedId, bytes calldata encryptedParam, address context) public override {
        require(false, "Only non-encrypted messages accepted");
    }
}
