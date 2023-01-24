// Your mission is to develop the smart-contracts of a mini Web3 bank infrastructure.
// MiniBank allows users to make basic banking operations (get balance, deposit, withdraw) and should support multiple tokens, i.e., USD,EUR,GBP. MiniBank needs to support new tokens in the future.
// Feel free to make assumptions, but please add comments or assertions describing the assumptions you are making.
// You should create one or multiple smart-contracts that implement your version of MiniBank.
// It should be written in Solidity. It should be an independent repository, complete with a README, tests, comments, and any other documentations expected in high quality software engineering.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@chainlink/interfaces/AggregatorV3Interface.sol";

contract MiniBank is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => mapping(address => uint256))
        public approvedForValueInUSD;
    mapping(address => bool) public whitelistedTokens;
    mapping(address => address) public tokenToOracle;

    constructor(address token, address oracle) {
        if (address == address(0) || oracle == address(0)) {
            revert AddressZero();
        }
        whitelistedTokens[token] = true;
        tokenToOracle[token] = oracle;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERACTIONS
    //////////////////////////////////////////////////////////////*/

    function deposit(
        address _token,
        uint256 _amount,
        address _receiver
    ) public onlyWhitelistedToken(token) nonReentrant {
        // deposit a token to the bank
        IERC20(token).safeTransferFrom(_receiver, address(this), amount);

        _mint(_token, _receiver, _amount);

        emit Deposit(_receiver, token, amount);
    }

    function withdraw(
        address _token,
        uint256 _amount,
        address _receiver
    ) public nonReentrant onlyWhiteListedToken(_token) {
        // withdraw a token from the bank
        if (msg.sender != _receiver) {
            if (
                approvedForValueInUSD[_receiver][msg.sender] >
                getValueInUSD(_token, _amount)
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
    ) public onlyWhiteListedToken(_token) {
        // transfer a token to another user
        _burn(_token, msg.sender, _amount);
        _mint(_token, _to, _amount);
        emit Transfer(msg.sender, _to, _token, amount);
    }

    function transferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) public onlyWhiteListedToken(_token) {
        // transfer a token from another user
        if (msg.sender != from) {
            if (
                approvedForValueInUSD[from][msg.sender] >
                getValueInUSD(_token, _amount)
            ) {
                revert InsufficientApprovedAmount(
                    _amount,
                    approvedForValueInUSD[from][msg.sender]
                );
            }
        }

        _burn(_token, _from, _amount);
        _mint(_token, _to, _amount);
        emit Transfer(_from, _to, _token, amount);

        // TODO - check if receiver can hold balance on MiniBank
    }

    function approveValueInUSD(address _operator, uint256 _value)
        public
        returns (bool)
    {
        // value has to be scaled to 18 decimals
        // approve a token transfer
        approvedForValueInUSD[msg.sender][_operator] = _value;
        emit ApprovedForValue(msg.sender, operator, approved);

        // optional set expiry time for approval
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN
    //////////////////////////////////////////////////////////////*/

    function whitelistToken(address _token, address _oracle) public onlyOwner {
        if (address == address(0) || oracle == address(0)) {
            revert AddressZero();
        }
        // TODO - switch owner to timelock contract
        // whitelist a token
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
        balances[_to][token] += amount;
    }

    function _burn(
        address _token,
        address _from,
        uint256 _amount
    ) internal {
        // burn a token
        if (balances[_from][token] < amount) {
            revert InsufficientBalance(amount, balances[_from][token]);
        }

        balances[_from][token] -= amount;
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
        return _amount * uint256(getLatestPrice(_token));
    }

    function getBalance(address token, address _user)
        public
        view
        returns (uint256)
    {
        // TODO
        // get the balance of a token for the caller
        return balances[_user][token];
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

        if (priceFeed.decimals() < 18) {
            uint256 decimals = 10**(18 - (priceFeed.decimals()));
            price = price * int256(decimals);
        } else if (priceFeed.decimals() == 18) {
            price = price;
        } else {
            uint256 decimals = 10**((priceFeed.decimals() - 18));
            price = price / int256(decimals);
        }

        if (price <= 0) revert OraclePriceZero();

        if (answeredInRound < roundID) revert RoundIDOutdated();

        return price;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyWhitelistedToken(address token) {
        // only whitelisted tokens can be used
        if (whitelistedTokens[token] == false)
            revert TokenNotWhitelisted(token);
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
