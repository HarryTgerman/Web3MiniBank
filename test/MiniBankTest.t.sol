// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/MiniBank.sol";
import "./Mocks/MintableToken.sol";
import "./Mocks/MockOracle.sol";

contract MiniBankTest is Test {
    MiniBank public miniBank;
    MintableToken public euro;
    MintableToken public usd;
    MintableToken public gbp;
    MockOracle public euroOracle;
    MockOracle public usdOracle;
    MockOracle public gbpOracle;

    address USER1 = address(0x1);
    address USER2 = address(0x2);

    function setUp() public {
        euro = new MintableToken("Euro", "EUR");
        usd = new MintableToken("US Dollar", "USD");
        gbp = new MintableToken("British Pound", "GBP");
        euroOracle = new MockOracle(1 ether + 2 gwei);
        usdOracle = new MockOracle(1 ether);
        gbpOracle = new MockOracle(1 ether + 23 gwei);
        miniBank = new MiniBank(address(usd), address(usdOracle));
        miniBank.whitelistToken(address(euro), address(euroOracle));
        miniBank.whitelistToken(address(gbp), address(gbpOracle));
    }

    // test INTERACTIONS functions
    function test_deposit() public {
        vm.startPank(USER1)
        usd.mint(USER1, 100);
        usd.approve(address(miniBank), 100);
        miniBank.deposit(address(usd), 100, USER1);
        assertEq(miniBank.balances(address(usd), USER1), 100);

        euro.mint(USER1, 100);
        euro.approve(address(miniBank), 100);
        miniBank.deposit(address(euro), 100, USER1);
        assertEq(miniBank.balances(address(euro), USER1), 100);
        vm.stopPrank()
    }

    function test_withdraw() public {
        test_deposit();
        miniBank.withdraw(address(usd), 100, USER1);
        assertEq(miniBank.balances(address(usd), USER1), 0);
        miniBank.withdraw(address(euro), 100, USER1);
        assertEq(miniBank.balances(address(euro), USER1), 0);

        // test approvedForValueInUSD
        test_deposit();
        vm.startPank(USER1);
          miniBank.approveForValueInUSD(USER2, 10 ether);
        vm.stopPrank();
        // test approvedForValueInUSD
        vm.startPank(USER2);
            // revert if not enough approved
            vm.expectRevert(abi.encodeWithSelector(MiniBank.InsufficientApprovedAmount.selector, 100 ether, 10 ether));
                miniBank.withdraw(address(usd), 100 ether, USER1);
            // revert if amount is bigger than approved value in USD
            vm.expectRevert(abi.encodeWithSelector(MiniBank.InsufficientApprovedAmount.selector, 10 ether, 10 ether));
                miniBank.withdraw(address(gbp), 10 ether, USER1);
            // success case
            miniBank.withdraw(address(usd), 2 ether, USER1);
        vm.stopPrank();
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
