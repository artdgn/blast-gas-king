// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface GasKingGame {
    error Claimable(uint amount);

    event GasFeesClaimed(uint amount);
    event HillCreated(uint claimDelay, address hill);

    receive() external payable;

    function blast() external view returns (address);
    function claimFactoryGasAndETH() external returns (uint amount);
    function claimableRevert() external;
    function createHill(uint claimDelay) external returns (address hill);
    function hillAddresses(uint) external view returns (address);
    function lastHillIndex() external view returns (uint);
}

interface Hill {
    error Claimable(uint amount);

    event Burned(address indexed sender, bool indexed isWinning, uint amount, uint gas);
    event GasFeesClaimed(uint amount);
    event NewRound(uint roundIndex);
    event RoundWon(address indexed winner, uint amount, uint winnerPoints, uint totalPoints);

    fallback() external payable;

    receive() external payable;

    function blast() external view returns (address);
    function claimDelay() external view returns (uint);
    function claimWinnings() external returns (uint amount);
    function claimableRevert() external;
    function lastRoundIndex() external view returns (uint);
    function play(uint minGas) external;
    function players(address) external view returns (uint points, uint lastRoundPlayed);
    function rounds(uint)
        external
        view
        returns (uint lastCoronationTimestamp, address currentKing, uint totalPoints);
}
