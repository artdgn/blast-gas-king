# Gas King of the Hill - A Blast of a Game

Burn gas for points, claim everyone's refund. Wait longer to claim more.

## Quick Game Rules
Earn points and become the King of the Hill by burning gas. The game is played in rounds on various Hills.

The King can claim a refund for all gas burned during the round after a certain delay (`claimDelay`). Keep earning points during this time to maintain your lead. If someone else takes the lead, the wait time resets.

According to [Blast's rules](https://docs.blast.io/building/guides/gas-fees#claiming-gas-fees) refunds grow over time, from 50% to 100%.

Player Strategies:
- **First Player**: If no one challenges you, wait until 100% refund to get all your fees back.
- **Second Player**: Overtake the leader and you're guaranteed to earn more than what you spent, thanks to a minimum 50% fee claim.
- **Beyond Two Players**: More competition means profit for the winner is guaranteed.

## Big Bang Competition

- **Engaging Introduction to Blast**: Offers a fun, competitive platform for users to familiarize themselves with Blast's gas fee claiming mechanism.
- **User Value**: The game's mechanics are easy to grasp, and the risks are minimal.
- **Ecosystem Benefit**: Encourages early gas fee claims, benefiting the sequencer with high share of the fees while promoting network utilization.
- **Showcases Blast's Uniqueness**: Highlights a distinctive feature of Blast L2, demonstrating the platform's innovative approach to gas fee management.
- **Future Growth Potential**: Provides a foundation for more complex extensions, including additional reward systems like Blast points or reward NFTs.

## Contracts flow

1. `GasKingGame` contract is used to create `Hill`s (game servers) which differ only by `claimDelay`. There's 3 default hills (1 minutes, 1 hour, 1 day).
2. The `Hill` is where the game is played. Each player competes for points by burning gas via `play` (or via triggerring `fallback/receive` with any calldata).
3. The player with the most points can claim all the contract's (`Hill`'s) gas fees after they have been "king" longer than `claimDelay`.
4. After a successful claim, a new round of the game starts.
5. Historical data is saved for previous plays and accessible via `getRound`.
6. Claimable amount off-chain is accessible via `claimableSimulate`.

## Deployment on https://testnet.blastscan.io/:
1. `GasKingGame` (w. 3 default hills): 0xF64E27cbb8bc66745a0343f8a73b678e34Ba5fad

## Interfaces:

```solidity
interface GasKingGame {
  // mutative
  function createHill(uint claimDelay) external returns (address hill);

  // views
  function hillAddresses(uint) external view returns (address);
  function lastHillIndex() external view returns (uint);

  event HillCreated(uint claimDelay, address hill);
}

interface Hill {
  // mutative
  function burnForPoints() external payable;
  function claimWinnings() external returns (uint amount);
  receive() external payable;

  // mutative but should be used as view (via simulation)
  function claimableSimulate() external returns (uint claimable);

  // views
  function claimDelay() external view returns (uint);
  function lastRoundIndex() external view returns (uint);
  function getRound(uint roundIndex) external view returns (Round memory);
  function players(address) external view returns (uint points, uint lastRoundPlayed);

  // view structs
  struct PlayHistory {
      address player;
      uint points;
      uint timestamp;
  }

  struct Round {
      uint lastCoronationTimestamp;
      address currentKing;
      uint totalPoints;
      uint winnings;
      PlayHistory[] plays;
  }

  // events
  event Burned(
        address indexed sender, uint indexed roundIndex, bool indexed isWinning, uint amount, uint gas
  );
  event GasFeesClaimed(uint amount);
  event NewRound(uint roundIndex);
  event RoundWon(address indexed winner, uint roundIndex, uint amount, uint winnerPoints, uint totalPoints);
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
