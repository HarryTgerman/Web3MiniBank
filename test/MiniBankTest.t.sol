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
    address ADMIN;

    function setUp() public {
        euro = new MintableToken("Euro", "EUR");
        usd = new MintableToken("US Dollar", "USD");
        gbp = new MintableToken("British Pound", "GBP");
        euroOracle = new MockOracle(1 ether + 200 gwei);
        usdOracle = new MockOracle(1 ether);
        gbpOracle = new MockOracle(1 ether + 2300 gwei);
        miniBank = new MiniBank(address(usd), address(usdOracle));
        miniBank.whitelistToken(address(euro), address(euroOracle));
        miniBank.whitelistToken(address(gbp), address(gbpOracle));
        ADMIN = address(this);
        vm.roll(1);
    }

    // test INTERACTIONS functions
    function test_deposit() public {
        vm.startPrank(USER1);
        usd.mint(USER1, 1000 ether);
        usd.approve(address(miniBank), 100 ether);
        miniBank.deposit(address(usd), 100 ether, USER1);
        assertEq(miniBank.balanceOf(address(usd), USER1), 100 ether);

        euro.mint(USER1, 100 ether);
        euro.approve(address(miniBank), 100 ether);
        miniBank.deposit(address(euro), 100 ether, USER1);
        assertEq(miniBank.balanceOf(address(euro), USER1), 100 ether);
        vm.stopPrank();
    }

    function test_withdraw() public {
        // test withdraw without approvedForValueInUSD
        test_deposit();
        vm.startPrank(USER1);
        miniBank.withdraw(address(usd), 100 ether, USER1);
        assertEq(miniBank.balanceOf(address(usd), USER1), 0);
        miniBank.withdraw(address(euro), 100 ether, USER1);
        assertEq(miniBank.balanceOf(address(euro), USER1), 0);
        vm.stopPrank();
        // test approvedForValueInUSD
        test_deposit();
        vm.startPrank(USER1);
        miniBank.approve(USER2, 10 ether); // approve USD value
        vm.stopPrank();
        // test approvedForValueInUSD
        vm.startPrank(USER2);
        console.log();
        // revert if not enough approved
        vm.expectRevert(
            abi.encodeWithSelector(
                MiniBank.InsufficientApprovedAmount.selector,
                100 ether,
                10 ether
            )
        );
        miniBank.withdraw(address(usd), 100 ether, USER1);
        // revert if amount is bigger than approved value in USD
        vm.expectRevert(
            abi.encodeWithSelector(
                MiniBank.InsufficientApprovedAmount.selector,
                10 ether,
                10 ether
            )
        );
        miniBank.withdraw(address(gbp), 10 ether, USER1);
        // success case
        miniBank.withdraw(address(usd), 2 ether, USER1);
        vm.stopPrank();
    }

    // test transfer functions
    function test_transfer() public {
        test_deposit();
        vm.startPrank(USER1);
        miniBank.transfer(address(usd), USER2, 100 ether);
        assertEq(miniBank.balanceOf(address(usd), USER1), 0);
        assertEq(miniBank.balanceOf(address(usd), USER2), 100 ether);
        miniBank.transfer(address(euro), USER2, 100 ether);
        assertEq(miniBank.balanceOf(address(euro), USER1), 0);
        assertEq(miniBank.balanceOf(address(euro), USER2), 100 ether);
        vm.stopPrank();
    }

    function test_approve() public {
        test_deposit();
        vm.startPrank(USER1);
        miniBank.approve(USER2, 100 ether); // approve value in USD Terms
        assertEq(miniBank.allowance(USER1, USER2), 100 ether);
        vm.stopPrank();
    }

    function test_transferFrom() public {
        // test transfer base currency
        vm.roll(2123);
        test_deposit();
        vm.startPrank(USER1);
        miniBank.approve(USER2, 100 ether); // approve value in USD Terms
        vm.stopPrank();
        vm.startPrank(USER2);
        miniBank.transferFrom(address(usd), USER1, USER2, 100 ether);
        assertEq(miniBank.balanceOf(address(usd), USER1), 0);
        assertEq(miniBank.balanceOf(address(usd), USER2), 100 ether);
        vm.stopPrank();

        // test revert if transfer base currency but not enough approved
        vm.startPrank(USER1);
        miniBank.approve(USER2, 100 ether); // approve value in USD Terms
        vm.stopPrank();
        vm.startPrank(USER2);
        vm.expectRevert(
            abi.encodeWithSelector(
                MiniBank.InsufficientApprovedAmount.selector,
                110 ether,
                100 ether
            )
        );
        miniBank.transferFrom(address(usd), USER1, USER2, 110 ether);
        vm.stopPrank();
        // test revert if value of amount is bigger than approved value in USD
        vm.startPrank(USER1);
        miniBank.approve(USER2, 100 ether); // approve value in USD Terms
        vm.stopPrank();
        vm.startPrank(USER2);
        vm.expectRevert(
            abi.encodeWithSelector(
                MiniBank.InsufficientApprovedAmount.selector,
                100 ether,
                100 ether
            )
        );
        miniBank.transferFrom(address(gbp), USER1, USER2, 100 ether);
        vm.stopPrank();
    }

    // test ADMIN functions
    function test_addTokenToWhitelist() public {
        // test revert if not admin
        vm.startPrank(USER1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        miniBank.whitelistToken(address(euro), address(euroOracle));
        vm.stopPrank();

        // test revert if address is zero
        vm.startPrank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(MiniBank.AddressZero.selector));
        miniBank.whitelistToken(address(0), address(euroOracle));
        vm.stopPrank();

        // test revert if oracle is zero
        vm.startPrank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(MiniBank.AddressZero.selector));
        miniBank.whitelistToken(address(euro), address(0));
        vm.stopPrank();

        // test success case
        vm.startPrank(ADMIN);
        miniBank.whitelistToken(address(euro), address(euroOracle));
        vm.stopPrank();
        assertTrue(miniBank.whitelistedTokens(address(euro)));
        assertEq(miniBank.tokenToOracle(address(euro)), address(euroOracle));
    }
}
