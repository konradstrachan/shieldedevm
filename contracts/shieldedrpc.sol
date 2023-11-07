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

contract ShieldedRPC is EIP712{
    bytes32 immutable typedDataHash;
    IMailbox public mailbox;

    // Storage for example logic
    mapping(address => euint32) internal balances;

    struct Message {
        string eventName;
        uint256 param;
    }

    constructor() EIP712("ShieldedRPC", "1") {
        typedDataHash = keccak256("Message(string eventName,uint256 param,address signedBy)");
        // Mailbox on Inco according to
        // https://www.notion.so/Cross-Chain-d9ac0f03d65e48399c6c38ac6e85c3cb
        mailbox = IMailbox(0x4B6ba9EDb2BE6753d95665B2D53766a9c889D9Ce);
    }

    function acceptMessage(string calldata eventName, uint256 param, bytes memory signature) public {
        Message memory message = Message(eventName, param);
        address signer = _verify(message, signature);
        
        // pass on execution to a logic handler on behalf of signer
        if (keccak256(bytes(eventName)) == keccak256(bytes("add"))) {
            balances[signer] = TFHE.add(balances[signer], TFHE.asEuint32(param));

            // return result to invoker
            uint32 result = TFHE.decrypt(balances[signer]);
            sendMessage(signer, abi.encodePacked(result));
        }
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
                    keccak256(bytes(message.eventName)),
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