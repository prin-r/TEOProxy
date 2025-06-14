// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ITssVerifier} from "tunnel-tss-router-contracts/interfaces/ITssVerifier.sol";
import {IPriceData} from "./IPriceData.sol";

interface ITEOProxy {
    // Custom Errors
    error InvalidProofLength();
    error VerificationFail();
    error InvalidOriginatorHash();
    error EncoderTypeNotPartialABI();
    error RequestNotSuccessfullyResolved();
    error OracleScriptIDMismatch();
    error InvalidMinCount();
    error InvalidTimestamp();

    // Events
    event SetMinCount(uint8 minCount);
    event SetBridge(address indexed newBridge);
    event SetOracleScriptID(uint64 newOID);
    event SetOriginatorHash(bytes32 newOriginatorHash);

    // Structs
    struct Config {
        uint8 minCount;
        uint64 oracleScriptID;
        ITssVerifier bridge;
        bytes32 originatorHash;
    }

    // External Functions
    function relay(IPriceData consumer, bytes calldata relayData) external;
}
