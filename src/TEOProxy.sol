// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ITssVerifier} from "tunnel-tss-router-contracts/interfaces/ITssVerifier.sol";
import {PacketDecoder} from "./libraries/PacketDecoder.sol";
import {ResultDecoder} from "./libraries/ResultDecoder.sol";
import {IPriceData} from "./interfaces/IPriceData.sol";
import {ITEOProxy} from "./interfaces/ITEOProxy.sol";

contract TEOProxy is ITEOProxy, Ownable, ReentrancyGuard {
    using PacketDecoder for bytes;
    using ResultDecoder for bytes;

    Config public config;
    uint64 public lastResolveTime;

    constructor(
        uint8 _minCount,
        uint32 _oracleScriptID,
        ITssVerifier _bridge,
        address _owner,
        bytes32 _originatorHash
    ) Ownable(_owner) {
        config.minCount = _minCount;
        config.bridge = _bridge;
        config.oracleScriptID = _oracleScriptID;
        config.originatorHash = _originatorHash;

        emit SetMinCount(config.minCount);
        emit SetBridge(address(config.bridge));
        emit SetOracleScriptID(config.oracleScriptID);
        emit SetOriginatorHash(config.originatorHash);
    }

    function setMinCount(uint8 _minCount) external onlyOwner {
        config.minCount = _minCount;
        emit SetMinCount(config.minCount);
    }

    function setBridge(ITssVerifier _bridge) external onlyOwner {
        config.bridge = _bridge;
        emit SetBridge(address(config.bridge));
    }

    function setOracleScriptID(uint32 _oracleScriptID) external onlyOwner {
        config.oracleScriptID = _oracleScriptID;
        emit SetOracleScriptID(config.oracleScriptID);
    }

    function setOriginatorHash(bytes32 _originatorHash) external onlyOwner {
        config.originatorHash = _originatorHash;
        emit SetOriginatorHash(config.originatorHash);
    }

    function relay(
        IPriceData consumer,
        bytes calldata relayData
    ) external nonReentrant {
        // Ensure the relayData is long enough to contain rAddress (20 bytes) and s (32 bytes)
        if (relayData.length < 52) {
            revert InvalidProofLength();
        }

        // Extract rAddress: first 20 bytes
        // Solidity allows direct slicing and casting for fixed-size bytes types.
        address raddr = address(bytes20(relayData[0:20]));

        // Extract s: next 32 bytes (from byte 20 to byte 51, inclusive)
        uint256 s = uint256(bytes32(relayData[20:52]));

        // Extract m: the remaining bytes from byte 52 to the end
        // If relayData.length is exactly 52, m will be an empty bytes array.
        bytes memory m = relayData[52:];

        Config memory c = config;

        if (!c.bridge.verify(keccak256(m), raddr, s)) {
            revert VerificationFail();
        }

        PacketDecoder.TssMessage memory tssm = m.decodeTssMessage();

        if (tssm.originatorHash != c.originatorHash) {
            revert InvalidOriginatorHash();
        }

        if (tssm.encoderType != PacketDecoder.EncoderType.PARTIAL_ABI) {
            revert EncoderTypeNotPartialABI();
        }

        PacketDecoder.PartialResult memory res = tssm
            .packet
            .decodePartialResult();

        if (
            res.resolveStatus !=
            PacketDecoder.ResolveStatus.RESOLVE_STATUS_SUCCESS
        ) {
            revert RequestNotSuccessfullyResolved();
        }

        if (res.oracleScriptID != uint64(c.oracleScriptID)) {
            revert OracleScriptIDMismatch();
        }

        if (res.minCount < c.minCount) {
            revert InvalidMinCount();
        }

        if (res.resolveTime <= lastResolveTime) {
            revert InvalidTimestamp();
        }

        lastResolveTime = res.resolveTime;

        (string[] memory keys, uint256[] memory values) = res
            .result
            .decodeResult();
        consumer.setPrices(keys, values);
    }
}
