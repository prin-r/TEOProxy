# TEOProxy

**TEOProxy** is a custom cross-chain oracle proxy contract designed to connect a consumer’s smart contract to Band Protocol’s TssVerifier via a specific oracle script. In your setup:

1. **Oracle Script**: The logic for fetching and formatting data lives in the Band Protocol oracle script: [https://band-v3-testnet.cosmoscan.io/oracle-script/14#code](https://band-v3-testnet.cosmoscan.io/oracle-script/14#code)
2. **Consumer Contract**: Your on-chain consumer implements a simple interface (e.g. [`MockConsumer.sol`](src/mocks/MockConsumer.sol)) that calls into TEOProxy and only accepts validated responses.
3. **TssVerifier**: Proofs submitted through TEOProxy are verified against Band Protocol’s TssVerifier: [https://github.com/bandprotocol/tunnel-tss-router-contracts/blob/main/src/TssVerifier.sol](https://github.com/bandprotocol/tunnel-tss-router-contracts/blob/main/src/TssVerifier.sol)

This repo contains:

* The TEOProxy Solidity contracts (`src/TEOProxy.sol`, mocks, interfaces, tests)
* A Python 3 relayer (`relayer_script.py`) showcasing the full request→relay→verify→fulfill loop
* Example interactions in JavaScript and Python under `src/example_interactions/`

## 📦 Features

* **Example contracts**: This serves as a template for developers building a custom proxy to connect their consumer DApp with Band’s TssVerifier.
* **Example relayer**: It continuously polls for new requests, fetches data from the Band oracle, and relays the signed result to the TEOProxy contract on the EVM. BandChain parameters (chain ID, RPC endpoint, gas limits) and EVM settings are located at the top of the script for easy customization.

---

## 🏗 Architecture

![img_arc](/imgs/img_arc.png)

---

## 🚀 Quickstart

### Prerequisites

* **Foundry** (for compiling/deploying Solidity)
* **Python 3.10**
* An account on **BandChain** (`band-v3-testnet.bandchain.org`) with some native tokens
* An account on EVM‑compatible chain with some native tokens

### Install

```bash
git clone https://github.com/prin-r/TEOProxy.git
cd TEOProxy

# Install Solidity deps (if using Foundry)
forge install
```

### Run the Python relayer (Example interactions)

See [src/example\_interactions/README.md](src/example_interactions/README.md)             |

---

### 🚨 An error that may occur

If you encounter an error like below when relaying data:

![img_err](/imgs/img_err.png)

it **may be** due to a mismatch between the originator hash your proxy contract expects and the one used in your BandChain request. The proxy computes an `originatorHash` from the `sourceChainID`, `requesterAddress`, and `memo`. Make sure these values (especially the `requesterAddress` and `memo`) match exactly what you registered on BandChain.

```solidity
bytes4 public constant DirectOriginatorPrefix = 0xb39fa5d2;

function calOriginatorHash(
    string memory sourceChainID,
    string memory requesterAddress,
    string memory memo
) public pure returns (bytes32 originatorHash) {
    originatorHash = keccak256(
        abi.encodePacked(
            DirectOriginatorPrefix,
            keccak256(abi.encodePacked(sourceChainID)),
            keccak256(abi.encodePacked(requesterAddress)),
            keccak256(abi.encodePacked(memo))
        )
    );
}
```

Double‑check that your BandChain oracle request used the same `sourceChainID`, `requesterAddress`, and `memo`, so that the proxy’s `calOriginatorHash` matches the on‑chain value.

---

## 🧪 Testing

```bash
forge test
```
---

## 🤝 Contributing

Contributions welcome! Please open issues or pull requests for bug fixes, feature requests, or documentation improvements.

---

## 📄 License

This project is licensed under the MIT License.
