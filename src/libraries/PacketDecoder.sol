// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title PacketDecoder
/// @notice Decode TSS packets and Band oracle results.
library PacketDecoder {
    bytes8 private constant _PROTO_ENCODER_SELECTOR = 0x89cbf5af01e2adb3; // keccak256("oracle")[:4] + keccak256("Proto")[:4];
    bytes8 private constant _FULL_ABI_ENCODER_SELECTOR = 0x89cbf5af45b4e7ea; // keccak256("oracle")[:4] + keccak256("FullABI")[:4];
    bytes8 private constant _PARTIAL_ABI_ENCODER_SELECTOR = 0x89cbf5af7bae7cd8; // keccak256("oracle")[:4] + keccak256("PartialABI")[:4];

    enum EncoderType {
        UNSPECIFIED,
        PROTO,
        FULL_ABI,
        PARTIAL_ABI
    }

    enum ResolveStatus {
        RESOLVE_STATUS_OPEN_UNSPECIFIED,
        RESOLVE_STATUS_SUCCESS,
        RESOLVE_STATUS_FAILURE,
        RESOLVE_STATUS_EXPIRED
    }

    /// @notice TSS message structure (signed by TSS module)
    struct TssMessage {
        bytes32 originatorHash;
        uint64 sourceTimestamp;
        uint64 signingId;
        EncoderType encoderType;
        bytes packet;
    }

    /// @notice Band Full result
    struct FullResult {
        string clientID;
        uint64 oracleScriptID;
        bytes callData;
        uint64 askCount;
        uint64 minCount;
        uint64 requestID;
        uint64 ansCount;
        uint64 requestTime;
        uint64 resolveTime;
        ResolveStatus resolveStatus;
        bytes result;
    }

    /// @notice Band Partial result
    struct PartialResult {
        bytes callData;
        uint64 oracleScriptID;
        uint64 requestID;
        uint64 minCount;
        uint64 resolveTime;
        ResolveStatus resolveStatus;
        bytes result;
    }

    /**
     * @notice Decode the TSS message from a memory-encoded packet
     * @dev Layout in `message` (bytes memory):
     *      0..31   originatorHash (32 bytes)
     *      32..39  sourceTimestamp (8 bytes, u64 BE)
     *      40..47  signingId       (8 bytes, u64 BE)
     *      48..55  encoder selector (8 bytes, bytes8 BE)
     *      56..end packet payload (remaining bytes)
     * @param message Raw packet bytes (>=56 bytes)
     * @return tssMessage Decoded TssMessage struct
     */
    function decodeTssMessage(
        bytes memory message
    ) internal pure returns (TssMessage memory tssMessage) {
        require(message.length >= 56, "Packet too short");

        bytes32 originatorHash;
        uint64 sourceTimestamp;
        uint64 signingId;
        bytes8 selector;

        assembly {
            let data := add(message, 32)
            originatorHash := mload(data)
            sourceTimestamp := shr(192, mload(add(data, 32)))
            signingId := shr(192, mload(add(data, 40)))
            selector := mload(add(data, 48))
        }

        EncoderType enc = _toEncoderType(selector);

        uint256 pktLen = message.length - 56;
        bytes memory packet = new bytes(pktLen);
        assembly {
            let src := add(add(message, 32), 56)
            let dst := add(packet, 32)
            for {
                let end := add(src, pktLen)
            } lt(src, end) {
                src := add(src, 32)
                dst := add(dst, 32)
            } {
                mstore(dst, mload(src))
            }
        }

        tssMessage = TssMessage(
            originatorHash,
            sourceTimestamp,
            signingId,
            enc,
            packet
        );
    }

    /**
     * @notice Decode a full Band result from memory bytes
     * @param message ABI-encoded FullResult struct in memory
     * @return result Decoded FullResult
     */
    function decodeFullResult(
        bytes memory message
    ) internal pure returns (FullResult memory result) {
        result = abi.decode(message, (FullResult));
    }

    /**
     * @notice Decode a partial Band result from memory bytes
     * @param message ABI-encoded PartialResult struct in memory
     * @return result Decoded PartialResult
     */
    function decodePartialResult(
        bytes memory message
    ) internal pure returns (PartialResult memory result) {
        result = abi.decode(message, (PartialResult));
    }

    /**
     * @notice Map selector bytes8 to EncoderType enum
     * @param selector First 8 bytes of TSS packet
     * @return EncoderType corresponding to selector
     */
    function _toEncoderType(
        bytes8 selector
    ) private pure returns (EncoderType) {
        if (selector == _PROTO_ENCODER_SELECTOR) {
            return EncoderType.PROTO;
        } else if (selector == _FULL_ABI_ENCODER_SELECTOR) {
            return EncoderType.FULL_ABI;
        } else if (selector == _PARTIAL_ABI_ENCODER_SELECTOR) {
            return EncoderType.PARTIAL_ABI;
        } else {
            return EncoderType.UNSPECIFIED;
        }
    }
}
