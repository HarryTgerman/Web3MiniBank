// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract MintableToken is ERC20 {
    constructor(string name, string sym) ERC20(name, sym, 18) {}

    function mint(address _sender) public {
        _mint(_sender, 100 ether);
    }

    function mint(address _sender, uint256 _amount) public {
        _mint(_sender, _amount * 1 ether);
    }
}
