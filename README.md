# Gas King of the Hill - A Blast of a Game

Burn gas for points, claim everyone's refund. Wait longer to claim more.

## Game

1. `GasKingGame` is used to create `Hill`s (game servers) which differ only by `claimDelay`. There's a default hill with 1 hour delay.
2. The `Hill` is where the game is played. Each player competes for points by burning gas via `play` (or via triggerring `fallback/receive` with any calldata).
3. The player with the most points can claim all the contract's (`Hill`'s) gas fees after they have been "king" longer than `claimDelay`.
4. After a successful claim, a new round of the game starts.

## Deployments on https://testnet.blastscan.io/:
1. `GasKingGame`: 0x0133b68BF652aa732A46208a46178905803e77dD
2. Default `Hill` (1 hour): 0x8Cd49Ce143a0b6CEa62A17EfB092f215Dc7cbb25
3. 60 Second `Hill`: 0x3B254763671FEF91F42BEe28c0A693b2b63Fe183

## Interfaces:

```solidity
interface GasKingGame {
  // mutative
  function createHill(uint claimDelay) external returns (address hill);
  function claimFactoryGasAndETH() external returns (uint amount);
  function claimableRevert() external;
  receive() external payable;

  // views
  function hillAddresses(uint) external view returns (address);
  function lastHillIndex() external view returns (uint);

  event GasFeesClaimed(uint amount);
  event HillCreated(uint claimDelay, address hill);

  error Claimable(uint amount);
}

interface Hill {
  // mutative
  receive() external payable;
  fallback() external payable;
  function play(uint minGas) external;
  function claimWinnings() external returns (uint amount);
  function claimableRevert() external;

  // views
  function claimDelay() external view returns (uint);
  function lastRoundIndex() external view returns (uint);
  function players(address) external view returns (uint points, uint lastRoundPlayed);
  function rounds(uint)
    external
    view
    returns (uint lastCoronationTimestamp, address currentKing, uint totalPoints);

  event Burned(address indexed sender, bool indexed isWinning, uint amount, uint gas);
  event GasFeesClaimed(uint amount);
  event NewRound(uint roundIndex);
  event RoundWon(address indexed winner, uint amount, uint winnerPoints, uint totalPoints);

  error Claimable(uint amount);
}
```


-----------

## Template stuff

If this is your first time with Foundry, check out the
[installation](https://github.com/foundry-rs/foundry#installation) instructions.

## Features

This template builds upon the frameworks and libraries mentioned above, so please consult their respective documentation
for details about their specific features.

For example, if you're interested in exploring Foundry in more detail, you should look at the
[Foundry Book](https://book.getfoundry.sh/). In particular, you may be interested in reading the
[Writing Tests](https://book.getfoundry.sh/forge/writing-tests.html) tutorial.

### Sensible Defaults

This template comes with a set of sensible default configurations for you to use. These defaults can be found in the
following files:

```text
├── .editorconfig
├── .gitignore
├── .prettierignore
├── .prettierrc.yml
├── .solhint.json
├── foundry.toml
└── remappings.txt
```

### VSCode Integration

This template is IDE agnostic, but for the best user experience, you may want to use it in VSCode alongside Nomic
Foundation's [Solidity extension](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity).

For guidance on how to integrate a Foundry project in VSCode, please refer to this
[guide](https://book.getfoundry.sh/config/vscode).

### GitHub Actions

This template comes with GitHub Actions pre-configured. Your contracts will be linted and tested on every push and pull
request made to the `main` branch.

You can edit the CI script in [.github/workflows/ci.yml](./.github/workflows/ci.yml).

## Installing Dependencies

Foundry typically uses git submodules to manage dependencies, but this template uses Node.js packages because
[submodules don't scale](https://twitter.com/PaulRBerg/status/1736695487057531328).

This is how to install dependencies:

1. Install the dependency using your preferred package manager, e.g. `bun install dependency-name`
   - Use this syntax to install from GitHub: `bun install github:username/repo-name`
2. Add a remapping for the dependency in [remappings.txt](./remappings.txt), e.g.
   `dependency-name=node_modules/dependency-name`

Note that OpenZeppelin Contracts is pre-installed, so you can follow that as an example.

## Writing Tests

To write a new test contract, you start by importing [PRBTest](https://github.com/PaulRBerg/prb-test) and inherit from
it in your test contract. PRBTest comes with a pre-instantiated [cheatcodes](https://book.getfoundry.sh/cheatcodes/)
environment accessible via the `vm` property. If you would like to view the logs in the terminal output you can add the
`-vvv` flag and use [console.log](https://book.getfoundry.sh/faq?highlight=console.log#how-do-i-use-consolelog).

This template comes with an example test contract [Foo.t.sol](./test/GasKing.t.sol)

## Usage

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Deploy

Deploy to Anvil:

```sh
$ forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For this script to work, you need to have a `MNEMONIC` environment variable set to a valid
[BIP39 mnemonic](https://iancoleman.io/bip39/).

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ bun run lint
```

### Test

Run the tests:

```sh
$ forge test
```

Generate test coverage and output result to the terminal:

```sh
$ bun run test:coverage
```

Generate test coverage with lcov report (you'll have to open the `./coverage/index.html` file in your browser, to do so
simply copy paste the path):

```sh
$ bun run test:coverage:report
```

## Related Efforts

- [abigger87/femplate](https://github.com/abigger87/femplate)
- [cleanunicorn/ethereum-smartcontract-template](https://github.com/cleanunicorn/ethereum-smartcontract-template)
- [foundry-rs/forge-template](https://github.com/foundry-rs/forge-template)
- [FrankieIsLost/forge-template](https://github.com/FrankieIsLost/forge-template)

## License

This project is licensed under MIT.
