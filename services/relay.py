from flask import Flask, request, jsonify
from web3 import Web3, exceptions
from eth_account.messages import encode_defunct

app = Flask(__name__)

web3 = Web3(Web3.HTTPProvider('RPC_URL_HERE'))
PRIVATE_KEY = 'PRIVATE_KEY_HERE'

# Define the ABI for ShieldedRPC contract
SHIELDED_RPC_ABI = [
	{
		"inputs": [],
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "eventId",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "param",
				"type": "uint256"
			},
			{
				"internalType": "bytes",
				"name": "signature",
				"type": "bytes"
			}
		],
		"name": "acceptMessage",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	}
]


def sign_transaction(txn):
    signed_txn = web3.eth.account.sign_transaction(txn, private_key=PRIVATE_KEY)
    return signed_txn.rawTransaction

@app.route('/execute', methods=['POST'])
def execute_contract_function():
    data = request.get_json()

    # Extract input parameters
    contract_address = data.get('contract_address')
    event_id = data.get('event_id')
    param = data.get('param')
    signature = data.get('signature')

    # Verify the signature
    try:
        message = encode_defunct(text=f'{contract_address}{event_id}{param}')
        signer_address = web3.eth.account.recover_message(message, signature=signature)
    except exceptions.ValidationError as e:
        return jsonify({'error': 'Invalid signature'}), 400

    contract = web3.eth.contract(address=contract_address, abi=SHIELDED_RPC_ABI)

    # Prepare the transaction
    txn_data = contract.functions.acceptMessage(event_id, param, signature).buildTransaction({
        'gas': 2000000,
        'gasPrice': web3.toWei('50', 'gwei'),
        'from': signer_address,
        'nonce': web3.eth.getTransactionCount(signer_address),
    })

    # Sign the transaction
    signed_txn = sign_transaction(txn_data)

    # Send the transaction
    try:
        transaction_hash = web3.eth.sendRawTransaction(signed_txn)
    except exceptions.ValidationError as e:
        return jsonify({'error': 'Failed to send transaction'}), 500

    return jsonify({'transaction_hash': transaction_hash, 'signer_address': signer_address})

if __name__ == '__main__':
    app.run(debug=True)
