// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IPriceData} from "../interfaces/IPriceData.sol";

contract MockConsumer is IPriceData {
    address public owner;
    address public bandBridge;

    struct PriceData {
        uint256 price;
        uint256 lastUpdated;
    }

    mapping(string => PriceData) public prices;

    string[] public knownKeys;
    mapping(string => bool) public knownKeyExists;

    event PriceUpdated(string indexed key, uint256 price, uint256 timestamp);

    modifier onlyAuthorized() {
        require(
            msg.sender == bandBridge || msg.sender == owner,
            "Not authorized"
        );
        _;
    }

    constructor(address _bandBridge) {
        require(_bandBridge != address(0), "Invalid BandBridge address");
        owner = msg.sender;
        bandBridge = _bandBridge;
    }

    function setPrices(
        string[] calldata keys,
        uint256[] calldata values
    ) external onlyAuthorized {
        require(keys.length == values.length, "Length mismatch");

        for (uint256 i = 0; i < keys.length; i++) {
            PriceData storage existing = prices[keys[i]];

            if (!knownKeyExists[keys[i]]) {
                knownKeys.push(keys[i]);
                knownKeyExists[keys[i]] = true;
            }

            if (existing.price != values[i]) {
                existing.price = values[i];
                existing.lastUpdated = block.timestamp;

                emit PriceUpdated(keys[i], values[i], block.timestamp);
            }
        }
    }
}
