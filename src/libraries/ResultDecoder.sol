// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Obi} from "./Obi.sol";

library ResultDecoder {
    using Obi for Obi.Data;

    error EmptyKeys();
    error LengthMismatch();
    error DataNotFinished();

    function decodeResult(bytes memory _data)
        internal
        pure
        returns (string[] memory keys, uint256[] memory vals)
    {
        Obi.Data memory decoder = Obi.from(_data);

        uint32 lengthKeys = decoder.decodeU32();
        if (lengthKeys == 0) {
            revert EmptyKeys();
        }

        keys = new string[](lengthKeys);
        for (uint256 i = 0; i < lengthKeys; i++) {
            keys[i] = decoder.decodeString();
        }

        uint32 lengthVals = decoder.decodeU32();
        if (lengthKeys != lengthVals) {
            revert LengthMismatch();
        }

        vals = new uint256[](lengthVals);
        for (uint256 i = 0; i < lengthVals; i++) {
            vals[i] = uint256(decoder.decodeU64());
        }

        if (!decoder.finished()) {
            revert DataNotFinished();
        }
    }
}
