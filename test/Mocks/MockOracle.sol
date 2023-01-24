// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import "@chainlink/interfaces/AggregatorV3Interface.sol";

contract MockOracle {
    uint8 public decimals;
    int256 public priceSimulation;

    constructor(int256 _priceSimulation) {
        priceSimulation = _priceSimulation;
        decimals = 18;
    }

    function latestRoundData()
        public
        view
        returns (
            uint80 roundID1,
            int256 nowPrice1,
            uint256 startedAt1,
            uint256 timeStamp1,
            uint80 answeredInRound1
        )
    {
        return (
            uint80(0x1),
            priceSimulation,
            block.timestamp,
            block.timestamp,
            uint80(0x1)
        );
    }
}
