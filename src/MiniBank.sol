// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@chainlink/interfaces/AggregatorV3Interface.sol";

contract MiniBank is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    address immutable baseCurrency;
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => mapping(address => uint256))
        public approvedForValueInUSD;
    mapping(address => bool) public whitelistedTokens;
    mapping(address => address) public tokenToOracle;

    constructor(address _token, address _oracle) {
        if (_token == address(0) || _oracle == address(0)) {
            revert AddressZero();
        }
        whitelistedTokens[_token] = true;
        tokenToOracle[_token] = _oracle;
        baseCurrency = _token;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERACTIONS
    //////////////////////////////////////////////////////////////*/

    function deposit(
        address _token,
        uint256 _amount,
        address _receiver
    ) public tokenIsWhitelisted(_token) nonReentrant {
        // deposit a token to the bank
        IERC20(_token).safeTransferFrom(_receiver, address(this), _amount);

        _mint(_token, _receiver, _amount);

        emit Deposit(_receiver, _token, _amount);
    }

    function withdraw(
        address _token,
        uint256 _amount,
        address _receiver
    ) public tokenIsWhitelisted(_token) nonReentrant {
        // withdraw a token from the bank
        if (msg.sender != _receiver) {
            // check if value of amount is is big
            if (
                getValueInUSD(
                    baseCurrency,
                    approvedForValueInUSD[_receiver][msg.sender]
                ) < getValueInUSD(_token, _amount)
            ) {
                revert InsufficientApprovedAmount(
                    _amount,
                    approvedForValueInUSD[_receiver][msg.sender]
                );
            }
        }

        _burn(_token, _receiver, _amount);
        IERC20(_token).safeTransfer(_receiver, _amount);
    }

    function transfer(
        address _token,
        address _to,
        uint256 _amount
    ) public tokenIsWhitelisted(_token) {
        // transfer a token to another user
        _burn(_token, msg.sender, _amount);
        _mint(_token, _to, _amount);
        emit Transfer(msg.sender, _to, _token, _amount);
    }

    function transferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) public tokenIsWhitelisted(_token) {
        // transfer a token from another user
        if (msg.sender != _from) {
            if (
                getValueInUSD(
                    baseCurrency,
                    approvedForValueInUSD[_from][msg.sender]
                ) < getValueInUSD(_token, _amount)
            ) {
                revert InsufficientApprovedAmount(
                    _amount,
                    approvedForValueInUSD[_from][msg.sender]
                );
            }
        }

        _burn(_token, _from, _amount);
        _mint(_token, _to, _amount);
        emit Transfer(_from, _to, _token, _amount);

        // TODO - check if receiver can hold balance on MiniBank
    }

    function approve(address _operator, uint256 _value) public {
        // value has to be scaled to 18 decimals
        // value has to be based in USD terms
        _approveForValueInUSD(_operator, _value);
        // optional set expiry time for approval
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN
    //////////////////////////////////////////////////////////////*/

    function whitelistToken(address _token, address _oracle) public onlyOwner {
        if (_token == address(0) || _oracle == address(0)) {
            revert AddressZero();
        }
        // TODO - switch owner to timelock contract
        // whitelist token
        whitelistedTokens[_token] = true;
        tokenToOracle[_token] = _oracle;
        emit TokenWhitelisted(_token);
        emit OracleSet(_token, _oracle);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _mint(
        address _token,
        address _to,
        uint256 _amount
    ) internal {
        // mint a token
        balances[_to][_token] += _amount;
    }

    function _burn(
        address _token,
        address _from,
        uint256 _amount
    ) internal {
        // burn a token
        if (balances[_from][_token] < _amount) {
            revert InsufficientBalance(_amount, balances[_from][_token]);
        }

        balances[_from][_token] -= _amount;
    }

    function _approveForValueInUSD(address _operator, uint256 _value) internal {
        approvedForValueInUSD[msg.sender][_operator] = _value;
        emit ApprovedForValue(msg.sender, _operator, _value);

        // optional set expiry time for approval
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getValueInUSD(address _token, uint256 _amount)
        public
        view
        returns (uint256)
    {
        if (whitelistedTokens[_token] == false) return 0;
        // get the value of a token in USD
        // get oracle price of token
        return (_amount * uint256(getLatestPrice(_token))) / 1e18;
    }

    function getBalance(address _token, address _user)
        public
        view
        returns (uint256)
    {
        // TODO
        // get the balance of a token for the caller
        return balances[_user][_token];
    }

    /** @notice Lookup token price
     * @param _token Target token address
     * @return price of token normalized to 18 decimals
     */
    function getLatestPrice(address _token) public view returns (int256) {
        if (whitelistedTokens[_token] == false)
            revert TokenNotWhitelisted(_token);
        if (tokenToOracle[_token] == address(0)) revert OracleNotSet(_token);

        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            tokenToOracle[_token]
        );
        (uint80 roundID, int256 price, , , uint80 answeredInRound) = priceFeed
            .latestRoundData();

        uint256 decimals = priceFeed.decimals();

        if (decimals < 18) {
            decimals = 10**(18 - (decimals));
            price = price * int256(decimals);
        } else if (decimals == 18) {
            price = price;
        } else {
            decimals = 10**((decimals - 18));
            price = price / int256(decimals);
        }

        if (price <= 0) revert OraclePriceZero();

        if (answeredInRound < roundID) revert RoundIDOutdated();

        return price;
    }

    function allowance(address _owner, address _operator)
        public
        view
        returns (uint256)
    {
        // get the USD value of an approval for an operator
        // scale to 18 decimals
        return approvedForValueInUSD[_owner][_operator];
    }

    function balanceOf(address _token, address _user)
        public
        view
        returns (uint256)
    {
        // get the balance of a token for a user
        return balances[_user][_token];
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier tokenIsWhitelisted(address _token) {
        // only whitelisted tokens can be used
        if (whitelistedTokens[_token] == false)
            revert TokenNotWhitelisted(_token);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed from, address indexed token, uint256 amount);
    event Withdraw(address indexed from, address indexed token, uint256 amount);
    event ApprovedForValue(
        address indexed owner,
        address indexed operator,
        uint256 value
    );
    event Transfer(
        address indexed from,
        address indexed to,
        address indexed token,
        uint256 amount
    );
    event TokenWhitelisted(address indexed token);
    event OracleSet(address indexed token, address indexed oracle);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error InsufficientBalance(uint256 requested, uint256 available);
    error InsufficientApprovedAmount(uint256 requested, uint256 available);
    error TokenNotWhitelisted(address token);
    error OracleNotSet(address token);
    error OraclePriceZero();
    error RoundIDOutdated();
    error AddressZero();
}
