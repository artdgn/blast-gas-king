// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

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
