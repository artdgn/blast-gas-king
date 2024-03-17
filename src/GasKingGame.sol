// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

abstract contract GasClaimer {
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);

    event GasFeesClaimed(uint amount);

    constructor() {
        BLAST.configureClaimableGas();
        BLAST.configureAutomaticYield();
    }

    //////// External mutative ////////

    receive() external payable { }

    /// @notice used to simulate a claim using claimableRevert method to check how much is claimable
    function claimableSimulate() external returns (uint claimable) {
        (, bytes memory data) = address(this).call(abi.encodeCall(this.claimableRevert, ()));
        claimable = abi.decode(data, (uint));
    }

    /// @notice used by claimableSimulate to claim and revert because there's no view for this on blast
    function claimableRevert() external {
        uint claimable = _claimGas();
        assembly {
            mstore(0, claimable) // mstore it as revert reason
            revert(0, 32) // revert execution
        }
    }

    //////// Internal ////////

    function _claimGas() internal returns (uint claimed) {
        uint before = address(this).balance;
        BLAST.claimAllGas(address(this), address(this));
        claimed = address(this).balance - before;
        emit GasFeesClaimed(claimed);
    }
}

contract GasKingGame is GasClaimer {
    address[] public hillAddresses;

    event HillCreated(uint indexed claimDelay, address hill);

    constructor() {
        createHill(60);
        createHill(1 hours);
        createHill(1 days);
    }

    //////// External mutative ////////

    /// @notice create a new hill with a custom claimDelay
    function createHill(uint claimDelay) public returns (address hill) {
        hill = address(new Hill(claimDelay));
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
    uint internal constant GAS_SAFETY_BUFFER = 1000;

    /// @notice how long must the king wait after taking the lead before being able
    /// claim the pot for the round
    uint public immutable claimDelay;

    struct Player {
        uint points;
        uint lastRoundPlayed;
    }

    struct Round {
        // accounting fields (used as inputs)
        uint lastCoronationTimestamp;
        address currentKing;
        // historical fields for UI (not used as inputs, but as "subgraph")
        uint totalPoints;
        uint winnings;
        PlayHistory[] plays;
    }

    struct PlayHistory {
        address player;
        uint points;
        uint timestamp;
    }

    mapping(address => Player) public players;
    // @dev use getRound to get full struct (with nested array)
    Round[] public rounds;

    event Burned(
        address indexed sender, uint indexed roundIndex, bool indexed isWinning, uint amount, uint gas
    );
    event NewRound(uint roundIndex);
    event RoundWon(address indexed winner, uint roundIndex, uint amount, uint winnerPoints, uint totalPoints);

    constructor(uint _claimDelay) {
        require(_claimDelay > 0, "0 claim delay");
        require(_claimDelay < 30 days, "claim delay too long");
        claimDelay = _claimDelay;
        _startNewRound();
    }

    //////// External mutative ////////

    /// @notice burns all gas provided for points
    /// @dev needs at least 160K gas for first play in a round
    function burnForPoints() public {
        uint gas = gasleft() - GAS_SAFETY_BUFFER;
        uint newPoints = gas * tx.gasprice;

        uint roundIndex = lastRoundIndex();
        Player storage player = players[msg.sender];
        Round storage round = rounds[roundIndex];

        // update player data
        // add to previous points if already played during this round
        uint previousPoints = player.lastRoundPlayed == roundIndex ? player.points : 0;
        player.points = newPoints + previousPoints;
        player.lastRoundPlayed = roundIndex;

        // update round data
        bool isPlayerWinning = player.points > players[round.currentKing].points;
        if (isPlayerWinning && round.currentKing != msg.sender) {
            round.currentKing = msg.sender; // the king is dead, long live the king
            round.lastCoronationTimestamp = block.timestamp; // ta-da-da-da!!
        }

        // history
        round.totalPoints += newPoints;
        round.plays.push(PlayHistory(msg.sender, newPoints, block.timestamp));
        emit Burned(msg.sender, roundIndex, isPlayerWinning, newPoints, gas);

        // burn the rest
        uint i;
        while (gasleft() > GAS_SAFETY_BUFFER) {
            i++;
        }
    }

    /// @notice claims all gas fees and any ETH balance to sender if they are current round's king for
    /// longer than claimDelay. Then starts a new round.
    function claimWinnings() external returns (uint amount) {
        uint roundIndex = lastRoundIndex();
        Round storage round = rounds[roundIndex];
        require(msg.sender == round.currentKing, "not king of the hill");
        require(block.timestamp >= round.lastCoronationTimestamp + claimDelay, "not king long enough yet");

        // new round now before external calls
        _startNewRound();

        // claim winnings
        _claimGas();
        amount = address(this).balance;

        // history (for UI)
        round.winnings = amount;
        emit RoundWon(msg.sender, roundIndex, amount, players[msg.sender].points, round.totalPoints);

        // send
        (bool success,) = address(msg.sender).call{ value: amount }("");
        require(success, "ETH transfer failed");
    }

    //////// External views ////////

    function getRound(uint roundIndex) external view returns (Round memory) {
        return rounds[roundIndex];
    }

    function lastRoundIndex() public view returns (uint) {
        return rounds.length - 1;
    }

    //////// Internal ////////

    function _startNewRound() internal {
        rounds.push();
        emit NewRound(lastRoundIndex());
    }
}

interface IBlast {
    // yield
    function configureAutomaticYield() external;

    // gas
    function configureClaimableGas() external;
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint);
    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint);
}
