import asyncio
import time
from web3 import Web3
from eth_account import Account
from eth_account.signers.local import LocalAccount
from pyband import Client, Transaction, Wallet
from pyband.proto.cosmos.base.v1beta1 import Coin
from pyband.messages.band.oracle.v1 import MsgRequestData
from pyband.proto.band.oracle.v1 import Encoder
from pyband.proto.band.bandtss.v1beta1 import QuerySigningRequest

# ——— BandChain config ———
BAND_MNEMONIC = "<YOUR_BANDCHAIN_MNEMONIC>"
OS_ID = 14
MIN_REPORTERS_COUNT = 5
BAND_GRPC_URL = "band-v3-testnet.bandchain.org"
BAND_CLIENT_ID = "xrpl_example_script"
BAND_GAS_LIMIT = 330_000
BAND_GAS_PRICE = 0.0025
BAND_FEE_AMOUNT = "100000"
BAND_FEE_DENOM = "uband"
BAND_PREPARE_GAS = 1_000
BAND_EXECUTE_GAS = 6_000

# ——— EVM config ———
EVM_RPC_URL = "https://rpc.testnet.xrplevm.org"
EVM_CHAIN_ID = 1_449_000
EVM_GAS_LIMIT = 250_000
PRIVATE_KEY = "<YOUR_EVM_PRIVATE_KEY>"
CONSUMER_CONTRACT_ADDRESS = "0xA5461ED1740FD1eb190850BF94919e89AFFFb775"
BRIDGE_PROXY_CONTRACT_ADDRESS = "0x1bcE8bC03072932ff1941d8a9B026868b0265B7c"
BRIDGE_PROXY_CONTRACT_ABI = [
    {
        "inputs": [
            {
                "internalType": "contract IPriceData",
                "name": "consumer",
                "type": "address",
            },
            {"internalType": "bytes", "name": "relayData", "type": "bytes"},
        ],
        "name": "relay",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    }
]

# Polling
POLL_INTERVAL_SECONDS = 15
MAX_POLL_RETRIES = 10


async def _poll_for_result(async_action, label: str):
    """
    Polls an asynchronous action until it returns a truthy result or max retries are exceeded.
    """
    for i in range(MAX_POLL_RETRIES):
        try:
            result = await async_action()
            if result:
                print(f"✅ Found {label}: {result}")
                return result
        except Exception as e:
            print(f"🔄 Retry {i + 1}/{MAX_POLL_RETRIES} for {label}. Error: {e}")
        await asyncio.sleep(1)
    raise Exception(f"❌ Failed to retrieve {label} after {MAX_POLL_RETRIES} retries.")


async def get_band_relay_data() -> str:
    """
    Connects to BandChain, requests data, and retrieves the signed relay data.
    Returns the relay data as a hex string.
    """
    band_client = Client.from_endpoint(BAND_GRPC_URL, 443)
    chain_id = await band_client.get_chain_id()
    band_wallet = Wallet.from_mnemonic(BAND_MNEMONIC)
    sender_address = band_wallet.get_address().to_acc_bech32()
    print(
        f"🔗 Interacting with BandChain: Chain ID={chain_id}, Sender={sender_address}"
    )

    # Prepare and send the BandChain transaction
    account_info = await band_client.get_account(sender_address)
    msg = MsgRequestData(
        oracle_script_id=OS_ID,
        calldata=bytes([0]),
        ask_count=MIN_REPORTERS_COUNT + 1,
        min_count=MIN_REPORTERS_COUNT,
        client_id=BAND_CLIENT_ID,
        fee_limit=[Coin(amount=BAND_FEE_AMOUNT, denom=BAND_FEE_DENOM)],
        prepare_gas=BAND_PREPARE_GAS,
        execute_gas=BAND_EXECUTE_GAS,
        sender=sender_address,
        tss_encoder=Encoder.PARTIAL_ABI,
    )
    tx = (
        Transaction()
        .with_messages(msg)
        .with_sequence(account_info.sequence)
        .with_account_num(account_info.account_number)
        .with_chain_id(chain_id)
        .with_gas_limit(BAND_GAS_LIMIT)
        .with_gas_price(BAND_GAS_PRICE)
    )
    tx_block = await band_client.send_tx_sync_mode(band_wallet.sign_and_build(tx))
    print(f"💸 BandChain transaction sent. TxHash: {tx_block.txhash}")

    # Poll for Request ID
    async def _get_request_id():
        tx_response = await band_client.get_tx_response(tx_block.txhash)
        for event in tx_response.events:
            if event.type == "request":
                return next(
                    (attr.value for attr in event.attributes if attr.key == "id"), None
                )
        return None

    request_id_str = await _poll_for_result(_get_request_id, "BandChain Request ID")
    request_id = int(request_id_str)

    # Poll for Signing ID
    async def _get_signing_id():
        req = await band_client.get_request_by_id(request_id)
        return req.signing.signing_id if req.signing.signing_id > 0 else None

    signing_id = await _poll_for_result(_get_signing_id, "BandChain Signing ID")

    # Poll for Relay Data
    async def _get_relay_data():
        signing_data = await band_client.band_tss_query_stub.signing(
            QuerySigningRequest(signing_id)
        )
        result = signing_data.current_group_signing_result
        if result.evm_signature.signature:
            r_address = result.evm_signature.r_address.rjust(20, b"\x00")
            signature = result.evm_signature.signature.rjust(32, b"\x00")
            message = result.signing.message
            return "0x" + (r_address + signature + message).hex()
        return None

    relay_data = await _poll_for_result(_get_relay_data, "BandChain Relay Data")
    return relay_data


async def relay_to_evm_chain(relay_data: str):
    """
    Relays the retrieved relay_data to the specified bridge proxy contract on the EVM chain.
    """
    w3 = Web3(Web3.HTTPProvider(EVM_RPC_URL))

    if not w3.is_connected():
        raise Exception(f"Failed to connect to EVM RPC: {EVM_RPC_URL}")

    evm_account: LocalAccount = Account.from_key(PRIVATE_KEY)
    print(f"🔑 EVM Account Address: {evm_account.address}")

    bridge_contract = w3.eth.contract(
        address=Web3.to_checksum_address(BRIDGE_PROXY_CONTRACT_ADDRESS),
        abi=BRIDGE_PROXY_CONTRACT_ABI,
    )

    # Convert relay_data hex string to bytes
    relay_data_bytes = Web3.to_bytes(hexstr=relay_data)

    try:
        gas_price = w3.eth.gas_price
        nonce = w3.eth.get_transaction_count(evm_account.address)

        # Build the transaction
        transaction = bridge_contract.functions.relay(
            Web3.to_checksum_address(CONSUMER_CONTRACT_ADDRESS), relay_data_bytes
        ).build_transaction(
            {
                "from": evm_account.address,
                "chainId": EVM_CHAIN_ID,
                "gasPrice": gas_price,
                "gas": EVM_GAS_LIMIT,
                "nonce": nonce,
            }
        )

        # Sign and send the transaction
        signed_txn = w3.eth.account.sign_transaction(
            transaction, private_key=PRIVATE_KEY
        )
        tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)
        print(f"💸 EVM Transaction sent. TxHash: {tx_hash.hex()}")

        # Wait for transaction receipt
        tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=300)
        if tx_receipt.status == 1:
            print(f"✅ EVM Transaction successful! Block: {tx_receipt.blockNumber}")
        else:
            raise Exception(f"EVM Transaction failed! Receipt: {tx_receipt}")

    except Exception as e:
        print(f"❌ Error relaying to EVM: {e}")
        raise


async def main_loop():
    """
    Main loop to continuously fetch data from BandChain and relay it to the EVM chain.
    Errors are caught and printed, and the loop continues after an interval.
    """
    while True:
        print(f"\n--- Starting new relay cycle @ {time.ctime()} ---")
        try:
            relay_data = await get_band_relay_data()
            if relay_data:
                await relay_to_evm_chain(relay_data)
            else:
                print("⚠️ No relay data obtained from BandChain this cycle.")
        except Exception as e:
            print(f"❗ An error occurred during the relay cycle: {e}")
        finally:
            print(
                f"--- Cycle finished. Waiting for {POLL_INTERVAL_SECONDS} seconds... ---"
            )
            await asyncio.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    asyncio.run(main_loop())
