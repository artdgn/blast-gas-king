// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { console2 } from "forge-std/src/console2.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import { GasKingGame, Hill } from "../src/GasKingGame.sol";

contract MockBlast {
    function configureClaimableGas() external {}
    function configureAutomaticYield() external {}
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256) {
        payable(recipientOfGas).transfer(address(this).balance);
        return address(this).balance;
    }
    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256) {
        return 0;
    }
    receive() external payable {}
}

/// https://book.getfoundry.sh/forge/writing-tests
contract GasKingSetup is PRBTest, StdCheats {
    GasKingGame internal gasKing;
    MockBlast internal mockBlast;
    bool internal receiveReverts;

    address internal constant BLAST_ADDRESS = 0x4300000000000000000000000000000000000002;

    function setUp() public virtual {
        mockBlast = new MockBlast();
        vm.etch(address(BLAST_ADDRESS), address(mockBlast).code);
        gasKing = new GasKingGame();
    }

    receive() external payable {
        if (receiveReverts) {
            revert();
        }
    }
}


contract GasKingGameTest is GasKingSetup {

    event HillCreated(uint indexed, address);
    function testCreateHill() public {
        uint initialHillCount = gasKing.lastHillIndex() + 1;
        vm.expectEmit(true, true, false, false);
        emit HillCreated(1 days, address(this));
        gasKing.createHill(1 days);
        assertEq(gasKing.lastHillIndex() + 1, initialHillCount + 1, "Hill not created");
    }

    function testClaimFactoryGasAndETH() public {
        deal(address(BLAST_ADDRESS), 1 ether);
        uint initialBalance = address(this).balance;
        gasKing.claimFactoryGasAndETH();
        assertEq(address(this).balance, initialBalance + 1 ether, "Factory balance not claimed");
    }

    function testCreateHillZeroClaimDelay() public {
        vm.expectRevert("0 claim delay");
        gasKing.createHill(0);
    }

    function testCreateHillTooLongClaimDelay() public {
        vm.expectRevert("claim delay too long");
        gasKing.createHill(31 days);
    }

    function testCreateHillPublic() public {
        vm.prank(address(0));
        gasKing.createHill(1 days);
        assertEq(gasKing.lastHillIndex(), 3, "Hill not created by non-owner");
    }

    function testClaimFactoryGasAndETHTransferETHReverts() public {
        deal(address(BLAST_ADDRESS), 1 ether);
        deal(address(gasKing), 1 ether);

        receiveReverts = true;
        vm.expectRevert("ETH transfer failed");
        gasKing.claimFactoryGasAndETH();
    }
}

contract HillTest is GasKingSetup {
    Hill internal hill;
    uint constant GAS_PRICE = 1;

    function setUp() public override virtual {
        super.setUp();
        hill = new Hill(1 days);
        vm.txGasPrice(GAS_PRICE);
    }

    event Burned(address indexed, uint indexed, bool indexed, uint amount, uint gas);
    function testBurnForPointsSimple() public {
        (uint initialPoints,) = hill.players(address(this));
        Hill.Round memory round = hill.getRound(hill.lastRoundIndex());
        address initialKing = round.currentKing;
        uint initialTimestamp = round.lastCoronationTimestamp;
        assertEq(initialKing, address(0));
        assertEq(initialTimestamp, 0);
        assertEq(round.totalPoints, 0);
        assertEq(round.plays.length, 0);

        vm.expectEmit(true, true, true, false);
        uint gas = 200_000;
        emit Burned(address(this), hill.lastRoundIndex(), true, (gas - 1000) * GAS_PRICE, gas);
        hill.burnForPoints{gas: gas}();
        (uint newPoints,) = hill.players(address(this));
        assertGt(newPoints, initialPoints, "Points not awarded");
        round = hill.getRound(hill.lastRoundIndex());
        assertEq(round.currentKing, address(this), "Current king not updated");
        assertGt(round.lastCoronationTimestamp, initialTimestamp, "Timestamp not updated");
        assertLt(gas - 1000 - round.totalPoints, 1000, "Total points too low");
        assertEq(round.plays.length, 1, "Plays array not updated");
    }

    event RoundWon(address indexed, uint, uint, uint, uint);
    function testClaimWinningsSimple() public {
        hill.burnForPoints{gas: 200_000}();
        uint claimable = 200_000 * 1 / 2;
        deal(BLAST_ADDRESS, claimable);
        vm.warp(block.timestamp + hill.claimDelay() + 1);  // Increase time to pass claim delay
        uint initialBalance = address(this).balance;

        vm.expectEmit(true, true, false, false);
        emit RoundWon(address(this), hill.lastRoundIndex(), claimable, 200_000 * GAS_PRICE, 200_000 * GAS_PRICE);

        hill.claimWinnings();
        assertEq(address(this).balance, initialBalance + claimable, "Winnings not claimed");

        assertEq(hill.getRound(hill.lastRoundIndex() - 1).winnings, claimable, "Winnings not updated");
    }

    event GasFeesClaimed(uint);
    function testClaimWinningsGasFeesClaimedEvent() public {
        hill.burnForPoints{gas: 200_000}();
        deal(BLAST_ADDRESS, 1 ether);
        vm.warp(block.timestamp + hill.claimDelay() + 1);  // Increase time to pass claim delay

        vm.expectEmit(false, false, false, true);
        emit GasFeesClaimed(1 ether);
        hill.claimWinnings();
    }

    event NewRound(uint);
    function testClaimWinningsStartsNewRound() public {
        hill.burnForPoints{gas: 200_000}();
        vm.warp(block.timestamp + hill.claimDelay() + 1);
        uint initialRound = hill.lastRoundIndex();

        vm.expectEmit(true, false, false, true);
        emit NewRound(hill.lastRoundIndex() + 1);
        hill.claimWinnings();
        assertEq(hill.lastRoundIndex(), initialRound + 1, "New round not started");

        (, uint round) = hill.players(address(this));
        assertEq(round, initialRound, "wrong round");
    }

    function testOnlyKingCanClaimWinnings() public {
        vm.expectRevert("not king of the hill");
        hill.claimWinnings();
    }

    function testClaimWinningsBeforeDelayReverts() public {
        deal(address(this), 1 ether);
        hill.burnForPoints{gas: 200_000}();
        vm.expectRevert("not king long enough yet");
        hill.claimWinnings();
    }

    function testClaimableSimulate() public {
        uint claimable = hill.claimableSimulate();
        assertEq(claimable, 0, "Claimable amount incorrect");
        deal(address(BLAST_ADDRESS), 1 ether);
        claimable = hill.claimableSimulate();
        assertEq(claimable, 1 ether, "Claimable amount incorrect");
    }

    function testClaimableRevertReverts() public {
        deal(address(BLAST_ADDRESS), 1 ether);
        uint initialBalance = address(this).balance;

        vm.expectRevert();
        hill.claimableRevert();

        assertEq(address(this).balance, initialBalance, "No ETH should be claimed");
    }

    function testClaimWinningsTransferETHReverts() public {
        deal(address(BLAST_ADDRESS), 1 ether);
        deal(address(this), 1 ether);
        hill.burnForPoints{gas: 200_000}();
        vm.warp(block.timestamp + hill.claimDelay() + 1);

        receiveReverts = true;
        vm.expectRevert("ETH transfer failed");
        hill.claimWinnings();
    }

    function testPlayerOvertake() public {
        vm.prank(address(1));
        hill.burnForPoints{gas: 400_000}();

        vm.prank(address(2));
        hill.burnForPoints{gas: 200_000}();

        assertEq(hill.getRound(hill.lastRoundIndex()).currentKing, address(1), "Player 1 should be the current king");

        vm.prank(address(2));
        hill.burnForPoints{gas: 300_000}();

        assertEq(hill.getRound(hill.lastRoundIndex()).currentKing, address(2), "Player 2 should be the current king");

        (uint player1Points,) = hill.players(address(1));
        (uint player2Points,) = hill.players(address(2));
        assertGt(player2Points, player1Points, "Player 2 should have more points than Player 1");
    }

}



//    /// @dev Fork test that runs against an Ethereum Mainnet fork. For this to work, you need to set
//    /// `API_KEY_ALCHEMY`
//    /// in your environment You can get an API key for free at https://alchemy.com.
//    function testFork_Example() external {
//        // Silently pass this test if there is no API key.
//        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
//        if (bytes(alchemyApiKey).length == 0) {
//            return;
//        }
//
//        // Otherwise, run the test against the mainnet fork.
//        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 16_428_000 });
//        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
//        address holder = 0x7713974908Be4BEd47172370115e8b1219F4A5f0;
//        uint actualBalance = IERC20(usdc).balanceOf(holder);
//        uint expectedBalance = 196_307_713.810457e6;
//        assertEq(actualBalance, expectedBalance);
//    }
