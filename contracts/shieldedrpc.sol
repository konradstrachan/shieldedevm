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

    // Signatures for functions that must be implemented in derrived classes
    function handleMessage(uint256 eventId, uint256 param, address context) public virtual;
    function handleEncryptedMessage(bytes calldata encryptedParam, bytes calldata encryptedParam, address context) public virtual;

    constructor() EIP712("ShieldedRPC", "1") {
        typedDataHash = keccak256("Message(uint256 eventId,uint256 param,address signedBy)");
        // Mailbox on Inco according to
        // https://www.notion.so/Cross-Chain-d9ac0f03d65e48399c6c38ac6e85c3cb
        mailbox = IMailbox(0x4B6ba9EDb2BE6753d95665B2D53766a9c889D9Ce);
    }

    /////////////////////////////////////////////
    // Public functions

    // Handles encrypted message from RPC and calls
    // message handler in derrived contract
    function acceptMessage(uint256 eventId, uint256 param, bytes memory signature) public {
        Message memory message = Message(eventId, param);
        address signer = _verify(message, signature);
        
        handleMessage(eventId, param, signer);
    }

    // Handles encrypted message from RPC and calls
    // message handler in derrived contract
    function acceptEncryptedMessage(bytes calldata encryptedId, bytes calldata encryptedParam, bytes memory signature) public {
        Message memory message = Message(eventId, param);
        address signer = _verify(message, signature);
        
        handleEncryptedMessage(encryptedId, encryptedParam, signer);
    }

    // Handles sending of messages on behalf of contract logic to unshielded
    // contract handling events on Scroll (or elsewhere that is supported by Hyperlane)
    function sendMessage(address destination, bytes memory data) public {
        uint32 scrollDomain = 534351;
        // TODO pay for message by sending some native tokens along with the execution
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
    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
