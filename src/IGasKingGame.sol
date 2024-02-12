// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

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
    function play(uint minGas) external payable;
    receive() external payable;
    fallback() external payable;
    function claimWinnings() external returns (uint amount);

    // mutative but should be used as view (via simulation)
    function claimableSimulate() external returns (uint claimable);

    // views
    function claimDelay() external view returns (uint);
    function lastRoundIndex() external view returns (uint);
    function getRound(uint roundIndex) external view returns (Round memory);
    function players(address) external view returns (uint points, uint lastRoundPlayed);
    function readGasParams()
        external
        view
        returns (uint etherSeconds, uint etherBalance, uint lastUpdated, uint8 gasMode);

    // view structs
    struct PlayHistory {
        address player;
        uint points;
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
