# Shielded RPC Prototype: Communication between Shielded and Unshielded Logic

## Overview

ShieldedRPC is an framework designed to address the challenges posed by the transparency of information in blockchain applications. Specifically, it enables secure communication between unshielded game or DeFi applications and shielded logic hosted on Inco. By providing a mechanism for transmitting plain text or encrypted messages via a RPCs to contracts deployed on Inco, this provides a solution for applications requiring privacy in a blockchain environment.

## Motivation

In traditional blockchain architectures, the transparency of state and state changes is a fundamental characteristic. However, this openness becomes a hurdle when certain applications demand privacy, particularly when participants should not have visibility into each other's actions. ShieldedRPC is motivated by the need to introduce a layer of privacy in decentralized applications (dApps) where the actions and states of users need to remain confidential.

Consider scenarios in decentralized gaming or financial applications where maintaining the privacy of actions or transactional details is crucial for the correct functioning of the application. With blockchains inherently providing open and inspectable information, achieving privacy becomes a challenge.

ShieldedRPC addresses this challenge by allowing developers to segregate logic between logic that can be open and logic that needs to be shielded.

![image](https://github.com/konradstrachan/shieldedevm/assets/21056525/5da122a3-7ff2-4284-8221-0278a97be5c5)

The former can remain predominantly on the chain of choice whilst the shileded logic is deployed on a blockchain with additional features to prevent disclosure. In the case of this project, Inco is chosen as the shileded blockchain owing to it's use of fhEVM extensions. The shielded and unshielded logics then interact via cross chain messaging mediated by Hyperlane.


## Key Features

- **RPC Reference Implementation:** Exposes an API server allowing the forwarding of encrypted parameters directly to a shielded Inco smart contract. This is crucial, as parameters encrypted with fhEVM can be large, making traditional cross-chain messaging impractical. The RPC forwards signed EIP712 transactions on behalf of callsers to the shielded logic on the Inco blockchain.

- **ShieldedRPC Inco Smart Contract Base Logic:** Provides a flexible and abstract contract that simplifies the creation of shielded logic. Contracts inheriting from ShieldedRPC gain access to all necessary functionality.

- **Examples:** The repository includes examples demonstrating the construction of shielded logic using ShieldedRPC, such as a rock-paper-scissors game.

## Repository Structure

- **`contracts/`**: Contains the source code for the ShieldedRPC contracts.

    - `shieldedrpc.sol`: The abstract contract providing the base logic for shielded communication.

    - `rockpaperscissors.sol`: An example implementation of the classic game rock paper scissors allowing multiple players to make moves that are not revealed to each other. The outcome of the game is then securely communicated.

    - `examples.sol`: Minimal contract that inherits from ShieldedRPC, showcasing how the abstract logic can be extended with custom functionality.

- **`services/`**: Contains the code for the supporting services that enable message passing gaslessly to the shielded contracts

- `relay.py`: Reference implementation of a API server that forwards signed messages using EIP712 messages to the Inco blockchain.

## Getting Started

To integrate ShieldedRPC into your project:

1. Clone the repository: `git clone https://github.com/konradstrachan/shieldedevm.git`
2. Explore the `contracts/` directory for the core implementation and for usage examples.
3. Set up and run the RPC reference server found in the `contracts/` directory. Required are a private key for an operator EOA account to forward signed txs and an RPC URL.

## License

This project is licensed under the MIT License
