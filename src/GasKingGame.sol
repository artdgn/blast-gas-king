// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

abstract contract GasClaimer {
    IBlast internal constant BLAST = IBlast(0x4300000000000000000000000000000000000002);

    event GasFeesClaimed(uint amount);

    /// @dev note that this is an error that's used as "view"
    error Claimable(uint amount);

    constructor() {
        BLAST.configureClaimableGas();
        BLAST.configureAutomaticYield();
    }

    //////// External mutative ////////

    receive() external payable virtual { }

    /// @notice this is used to simulate a claim using the claimableRevert method to understand how much is claimable
    function claimableSimulate() external returns (uint claimable) {
        (bool success, bytes memory data) = address(this).call(abi.encodeCall(this.claimableRevert, ()));
        assert(!success); // check that it reverts
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

    function readGasParams()
        external
        view
        returns (uint etherSeconds, uint etherBalance, uint lastUpdated, IBlast.GasMode)
    {
        return BLAST.readGasParams(address(this));
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

    event HillCreated(uint claimDelay, address hill);

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
    address internal constant GAS_CONTRACT = 0x4300000000000000000000000000000000000001;

    /// @notice how long must the king wait after taking the lead before being able claim the pot for the round
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
    }

    mapping(address => Player) public players;
    // @dev use getRound to get full struct (with nested array)
    Round[] public rounds;

    event Burned(address indexed sender, uint indexed roundIndex, bool indexed isWinning, uint amount, uint gas);
    event NewRound(uint roundIndex);
    event RoundWon(address indexed winner, uint roundIndex, uint amount, uint winnerPoints, uint totalPoints);

    constructor(uint _claimDelay) {
        require(_claimDelay > 0, "0 claim delay");
        require(_claimDelay < 30 days, "claim delay too long");
        claimDelay = _claimDelay;
        _startNewRound();
    }

    //////// External mutative ////////

    /// @notice receive is cheapest in terms of L1 calldata cost (which is not refunded)
    receive() external payable override {
        if (msg.sender != GAS_CONTRACT) { // GAS system address
            _burnGasForPoints();
        }
    }

    /// @notice fallback is most flexible
    fallback() external payable {
        _burnGasForPoints();
    }

    /// @notice receive is cheaper (in terms of L1 calldata cost), but this is easier to integrate with
    /// This just checks that at least minGas gas is provided, but burns everything if more is provided
    function play(uint minGas) external payable {
        require(gasleft() >= minGas, "not enough gas provided");
        _burnGasForPoints();
    }

    /// @notice claims all gas fees and any ETH balance to sender if they are current round's king for
    /// longer than claimDelay. Then starts a new round.
    function claimWinnings() external returns (uint amount) {
        Round storage round = rounds[lastRoundIndex()];
        require(msg.sender == round.currentKing, "not king of the hill");
        require(block.timestamp >= round.lastCoronationTimestamp + claimDelay, "not king long enough yet");

        // claim winnings
        _claimGas();
        amount = address(this).balance;

        // history (for UI)
        round.winnings = amount;
        emit RoundWon(msg.sender, lastRoundIndex(), amount, players[msg.sender].points, round.totalPoints);

        // new round now before external call
        _startNewRound();

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

    function _burnGasForPoints() internal {
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
            // the king is dead, long live the king
            round.currentKing = msg.sender;
            round.lastCoronationTimestamp = block.timestamp; // ta-da-da-da!!
        }

        // history
        round.totalPoints += newPoints;
        round.plays.push(PlayHistory(msg.sender, newPoints));
        emit Burned(msg.sender, roundIndex, isPlayerWinning, newPoints, gas);

        // burn the rest
        uint i;
        while (gasleft() > GAS_SAFETY_BUFFER) {
            i++;
        }
    }

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
    function readGasParams(address contractAddress)
        external
        view
        returns (uint etherSeconds, uint etherBalance, uint lastUpdated, GasMode);

    enum GasMode {
        VOID,
        CLAIMABLE
    }
}
