// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IPriceData} from "../interfaces/IPriceData.sol";
import {ITEOProxy} from "../interfaces/ITEOProxy.sol";

contract MockConsumerReentrance is IPriceData {
    ITEOProxy public bandBridge;
    IPriceData public nextConsumer;
    bytes public nextCalldata;

    modifier onlyAuthorized() {
        require(msg.sender == address(bandBridge), "Not authorized");
        _;
    }

    constructor(ITEOProxy _bandBridge) {
        require(
            address(_bandBridge) != address(0),
            "Invalid BandBridge address"
        );
        bandBridge = _bandBridge;
    }

    function setWhatToBeCalledNext(
        IPriceData _nextConsumer,
        bytes memory _nextCalldata
    ) external {
        nextConsumer = _nextConsumer;
        nextCalldata = _nextCalldata;
    }

    function setPrices(
        string[] calldata keys,
        uint256[] calldata values
    ) external onlyAuthorized {
        require(keys.length == values.length, "Length mismatch");
        bandBridge.relay(nextConsumer, nextCalldata);
    }
}
