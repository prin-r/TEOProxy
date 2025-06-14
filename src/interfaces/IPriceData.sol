// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceData {
    function setPrices(
        string[] calldata keys,
        uint256[] calldata values
    ) external;
}
