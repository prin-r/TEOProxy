# Band-EVM Data Relayer

A Python 3 script that acts as a cross‑chain data relayer: it continuously fetches real‑world oracle data from BandChain and submits it to an EVM‑compatible blockchain.

## Features

* **BandChain Oracle Requests**: Sends a `MsgRequestData` to BandChain’s oracle module.
* **TSS Relay Data Retrieval**: Polls for the aggregated signature payload from BandChain’s TSS network.
* **EVM Contract Integration**: Connects to any EVM JSON-RPC endpoint via `web3.py`.
* **Smart Contract Invocation**: Calls your proxy's `relay` method with the formatted payload.
* **Continuous Operation**: Runs in a loop with retry/backoff logic.

---

## Prerequisites

* **Python**: 3.10 or higher
* **BandChain account**: mnemonic with enough `uband` on `band-v3-testnet.bandchain.org`
* **EVM account**: private key with sufficient native tokens (e.g., XRP) on `rpc.testnet.xrplevm.org`

---

## Installation

```bash
# 1. Create & activate a virtualenv
python3.10 -m venv venv
source venv/bin/activate

# 2. Upgrade pip and install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

---

## Configuration

Open `relayer_script.py` and update the constants at the top:

```python
# --- BandChain Settings ---
BAND_MNEMONIC               = "<YOUR_BANDCHAIN_MNEMONIC>"
OS_ID                       = 14
MIN_REPORTERS_COUNT         = 5
BAND_GRPC_URL               = "band-v3-testnet.bandchain.org"
BAND_CLIENT_ID              = "xrpl_example_script"
BAND_GAS_LIMIT              = 330_000
BAND_GAS_PRICE              = 0.0025
BAND_FEE_AMOUNT             = "100000"
BAND_FEE_DENOM              = "uband"
BAND_PREPARE_GAS            = 1_000
BAND_EXECUTE_GAS            = 6_000

# --- EVM Settings ---
EVM_RPC_URL                 = "https://rpc.testnet.xrplevm.org"
EVM_CHAIN_ID                = 1_449_000
EVM_GAS_LIMIT               = 250_000
PRIVATE_KEY                 = "<YOUR_EVM_PRIVATE_KEY>"
CONSUMER_CONTRACT_ADDRESS   = "0xA5461ED1740FD1eb190850BF94919e89AFFFb775"
BRIDGE_PROXY_CONTRACT_ADDRESS = "0x1bcE8bC03072932ff1941d8a9B026868b0265B7c"
BRIDGE_PROXY_CONTRACT_ABI   = [ /* ABI of `relay(IPriceData,bytes)` */ ]

# --- Polling & Retry ---
POLL_INTERVAL_SECONDS       = 15
MAX_POLL_RETRIES            = 10
```

---

## Usage

Simply run the relayer in your activated environment:

```bash
python relayer_script.py
```

The script will log each cycle’s steps, including transaction hashes on both chains. It will keep running until you stop it (e.g., `Ctrl+C`).
