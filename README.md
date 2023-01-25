# MiniBank Contract

This is a simple contract that allows users to deposit, withdraw, and transfer whitelisted tokens.It is built for any EVM compatible blockchain and uses the Solidity programming language.

## Install

To install dependencies and compile contracts:

```bash
git clone https://github.com/HarryTgerman/Web3MiniBank && cd Web3MiniBank
```

### Foundry Tests

To install Foundry (assuming a Linux or macOS system):

```bash
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. To start Foundry, run:

```bash
foundryup
```

To install dependencies:

```
forge install
```

To compile contracts:

```bash
forge build
```

```bash
forge test
```

**Note**

The following modifiers are also available:

- Level 2 (-vv): Logs emitted during tests are also displayed.
- Level 3 (-vvv): Stack traces for failing tests are also displayed.
- Level 4 (-vvvv): Stack traces for all tests are displayed, and setup traces for failing tests are displayed.
- Level 5 (-vvvvv): Stack traces and setup traces are always displayed.

```bash
test forge test  -vv
```

For more information on foundry testing and use, see [Foundry Book installation instructions](https://book.getfoundry.sh/getting-started/installation.html).

## Audits

Disclaimer: This contract is not Auditeded, use at your own risk.

## License

This contract is licensed under the MIT License.
