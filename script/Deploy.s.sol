// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { GasKingGame } from "../src/GasKingGame.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public returns (GasKingGame foo) {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        foo = new GasKingGame();
        vm.stopBroadcast();
    }
}

/*
# testnet
forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url https://sepolia.blast.io --verifier-url
'https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan' --etherscan-api-key "verifyContract"
--verify -vvvv --with-gas-price 10000000

# to resume verification
# remove --broadcast, add --resume, add --private-keys KEY

# mainnet
forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url https://rpc.blast.io --etherscan-api-key "<KEY>"
--verify -vvvv --with-gas-price 10000000
*/
