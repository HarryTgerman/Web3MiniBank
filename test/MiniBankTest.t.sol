// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/MiniBank.sol";

contract MiniBankTest is Test {
    MiniBank public miniBank;

    function setUp() public {
        miniBank = new MiniBank();
    }

    // test INTERACTIONS functions
    function test_deposit() public {
        // TODO
    }

    function test_withdraw() public {
        // TODO
    }

    // test transfer functions
    function test_transfer() public {
        // TODO
    }

    function test_approve() public {
        // TODO
    }

    function test_transferFrom() public {
        // TODO
    }

    // test ADMIN functions
    function test_addTokenToWhitelist() public {
        // TODO
    }

    function test_setOracleForToken() public {
        // TODO
    }
}
