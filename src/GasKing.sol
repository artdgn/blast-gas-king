// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { IBlast } from "./IBlast.sol";

abstract contract GasClaimer {
    IBlast public immutable blast;

    event GasFeesClaimed(uint amount);

    error Claimable(uint amount);

    constructor(IBlast _blast) {
        blast = _blast;
        _blast.configureClaimableGas(); // set the gas fees to claimable
    }

    //////// External mutative ////////

    receive() external payable { }

    /// @notice this can be used to "simulate" a claim to understand how much is claimable
    function claimableRevert() external {
        uint claimable = _claimGas();
        revert Claimable(claimable);
    }

    //////// Internal ////////

    function _claimGas() internal returns (uint claimed) {
        uint before = address(this).balance;
        blast.claimAllGas(address(this), address(this));
        //        // claims only up to max claimable, and leaves the rest to mature later
        //        blast.claimMaxGas(address(this), address(this));
        claimed = address(this).balance - before;
        emit GasFeesClaimed(claimed);
    }
}

contract GasKingGame is GasClaimer {
    address[] public hillAddresses;

    event HillCreated(uint claimDelay, address hill);

    constructor(IBlast _blast) GasClaimer(_blast) {
        createHill(1 hours);
    }

    //////// External mutative ////////

    function createHill(uint claimDelay) public returns (address hill) {
        hill = address(new Hill(blast, claimDelay));
        hillAddresses.push(hill);
        emit HillCreated(claimDelay, hill);
    }

    /// @notice claim factory gas fees and any ETH balance to sender
    function claimFactoryGasAndETH() external returns (uint amount) {
        _claimGas();
        amount = address(this).balance;
        (bool success,) = address(msg.sender).call{ value: amount }(""); // so generous
        require(success, "ETH transfer failed");
    }

    //////// External views ////////

    function lastHillIndex() external view returns (uint) {
        return hillAddresses.length - 1;
    }
}

contract Hill is GasClaimer {
    /// @notice how long can the king wait since taking the lead before being able claim the whole pot
    uint public immutable claimDelay;

    uint internal constant GAS_SAFETY_BUFFER = 1000;

    struct Player {
        uint thisRoundPoints;
        uint lastBurnTimestamp;
    }

    mapping(address => Player) public players;

    struct Round {
        uint startTime;
        uint lastCoronationTimestamp;
        address currentKing;
        uint totalPoints;
    }

    Round[] public rounds;

    event Burned(address indexed sender, bool indexed isKing, uint amount, uint gas);
    event NewRound(uint roundIndex);
    event RoundWon(address winner, uint amount, uint winnerPoints, uint totalPoints);

    constructor(IBlast _blast, uint _claimDelay) GasClaimer(_blast) {
        require(_claimDelay > 0, "0 claim delay");
        claimDelay = _claimDelay;
        _startNewRound();
    }

    //////// External mutative ////////

    /// @notice fallback is cheapest in terms of L1 calldata cost (which are not refunded)
    fallback() external payable {
        _burnGasForPoints();
    }

    /// @notice fallback is cheaper (in terms of L1 calldata cost), but this is easier to integrate with
    /// This just checks that at least minGas gas is provided, but burns everything if more is provided
    function play(uint minGas) external {
        require(gasleft() >= minGas, "not enough gas provided");
        _burnGasForPoints();
    }

    /// @notice claims all gas fees and any ETH balance to sender if they are current round's king for
    /// longer than claimDelay. Then starts a new round.
    function claimWinnings() external {
        Round storage round = rounds[lastRoundIndex()];
        require(msg.sender == round.currentKing, "not king of the hill");
        require(block.timestamp >= round.lastCoronationTimestamp + claimDelay, "not king long enough yet");

        // claim and send winnings
        _claimGas();
        uint balance = address(this).balance;
        (bool success,) = address(msg.sender).call{ value: balance }("");
        require(success, "ETH transfer failed");
        emit RoundWon(msg.sender, balance, players[msg.sender].thisRoundPoints, round.totalPoints);

        // new round
        _startNewRound();
    }

    //////// External views ////////

    function lastRoundIndex() public view returns (uint) {
        return rounds.length - 1;
    }

    //////// Internal ////////

    function _burnGasForPoints() internal {
        uint gas = gasleft() - GAS_SAFETY_BUFFER;
        uint newPoints = gas * tx.gasprice;

        Player storage player = players[msg.sender];
        Round storage round = rounds[lastRoundIndex()];

        // use previous points if already played during this round
        uint previousPoints = player.lastBurnTimestamp > round.startTime ? player.thisRoundPoints : 0;

        // update player storage
        uint updatedPoints = previousPoints + newPoints;
        player.thisRoundPoints = updatedPoints;
        player.lastBurnTimestamp = block.timestamp;

        // top score is current king's points
        uint topScore = players[round.currentKing].thisRoundPoints;
        bool isPlayerWinning = topScore < updatedPoints;
        // update round
        if (isPlayerWinning) {
            if (round.currentKing != msg.sender) {
                round.lastCoronationTimestamp = block.timestamp; // ta-da-da-da!!
                round.currentKing = msg.sender;
            }
        }
        round.totalPoints += newPoints;

        emit Burned(msg.sender, isPlayerWinning, newPoints, gas);

        // burn the rest
        uint i;
        while (gasleft() > GAS_SAFETY_BUFFER) {
            i++;
        }
    }

    function _startNewRound() internal {
        rounds.push(Round(block.timestamp, block.timestamp, address(0), 0));
        emit NewRound(lastRoundIndex());
    }
}
