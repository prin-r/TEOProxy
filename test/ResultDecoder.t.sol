// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {ResultDecoder} from "../src/libraries/ResultDecoder.sol";

contract ResultDecoderTest is Test {

    function decodeResult(bytes calldata resultBytes) public pure returns (string[] memory, uint256[] memory) {
        return ResultDecoder.decodeResult(resultBytes);
    }

    function testDecodeResult_Success_MultipleEntries() public view {
        bytes
            memory encodedData = hex"0000000600000004476f6c640000000653696c76657200000006436f7070657200000008506c6174696e756d0000000948524320537465656c0000000849726f6e204f7265000000060000004fe87e2ec000000000d85be0e0000000001c40f8a00000001c2469d5800000001411eb9e000000000238825480";

        (string[] memory symbols, uint256[] memory prices) = this.decodeResult(encodedData);

        assertEq(symbols.length, 6);
        assertEq(prices.length, 6);

        assertEq(symbols[0], "Gold");
        assertEq(prices[0], 343203000000);

        assertEq(symbols[1], "Silver");
        assertEq(prices[1], 3629900000);

        assertEq(symbols[2], "Copper");
        assertEq(prices[2], 474020000);

        assertEq(symbols[3], "Platinum");
        assertEq(prices[3], 120870000000);

        assertEq(symbols[4], "HRC Steel");
        assertEq(prices[4], 86200000000);

        assertEq(symbols[5], "Iron Ore");
        assertEq(prices[5], 9538000000);
    }

    function testDecodeResult_Revert_LengthMismatch() public {
        // Encoded data:
        // lengthKeys = 1
        // Key: "Gold" (length 4)
        // lengthVals = 2 (mismatch with lengthKeys)
        // Values for 2 items (but only one key)
        bytes
            memory encodedData = hex"0000000100000004476f6c640000000200000000000000010000000000000002";

        vm.expectRevert(ResultDecoder.LengthMismatch.selector);
        this.decodeResult(encodedData);
    }

    function testDecodeResult_Revert_DataNotFinished_ExtraBytes() public {
        // Encoded data:
        // lengthKeys = 1
        // Key: "Gold" (length 4)
        // lengthVals = 1
        // Value: 1
        // PLUS 1 extra byte at the end
        bytes memory encodedData = hex"0000000100000004476f6c64000000010000000000000001ff";

        vm.expectRevert(ResultDecoder.DataNotFinished.selector);
        this.decodeResult(encodedData);
    }

    function testDecodeResult_Success_EmptyKeys() public {
        // Encoded data:
        // lengthKeys = 0
        // lengthVals = 0
        bytes memory encodedData = hex"0000000000000000";

        vm.expectRevert(ResultDecoder.EmptyKeys.selector);
        this.decodeResult(encodedData);
    }

    function testDecodeResult_Success_SingleEntry() public view {
        // Encoded data:
        // lengthKeys = 1
        // Key: "Single" (length 6)
        // lengthVals = 1
        // Value: 123
        bytes memory encodedData = hex"000000010000000653696e676c6500000001000000000000007b";

        (string[] memory symbols, uint256[] memory prices) = this.decodeResult(encodedData);

        assertEq(symbols.length, 1, "Single entry symbols array length mismatch");
        assertEq(prices.length, 1, "Single entry prices array length mismatch");
        assertEq(symbols[0], "Single", "Single entry symbol mismatch");
        assertEq(prices[0], 123, "Single entry price mismatch");
    }

    function testDecodeResult_Success_MaxUint64Prices() public view {
        // Encoded data:
        // lengthKeys = 1
        // Key: "MaxVal" (length 6)
        // lengthVals = 1
        // Value: type(uint64).max (0xFFFFFFFFFFFFFFFF)
        bytes memory encodedData = hex"00000001000000064d617856616c00000001ffffffffffffffff";

        (string[] memory symbols, uint256[] memory prices) = this.decodeResult(encodedData);

        assertEq(symbols.length, 1, "Max uint64 symbols array length mismatch");
        assertEq(prices.length, 1, "Max uint64 prices array length mismatch");
        assertEq(symbols[0], "MaxVal", "Max uint64 symbol mismatch");
        assertEq(prices[0], type(uint64).max, "Max uint64 price mismatch");
    }
}
