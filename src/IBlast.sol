// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

enum YieldMode {
    AUTOMATIC,
    VOID,
    CLAIMABLE
}

enum GasMode {
    VOID,
    CLAIMABLE
}

interface IBlast {
    // configure
    function configureContract(
        address contractAddress,
        YieldMode _yield,
        GasMode gasMode,
        address governor
    )
        external;
    function configure(YieldMode _yield, GasMode gasMode, address governor) external;

    // base configuration options
    function configureClaimableGas() external;
    function configureGovernor(address _governor) external;

    // claim gas
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint);
    function claimGasAtMinClaimRate(
        address contractAddress,
        address recipientOfGas,
        uint minClaimRateBips
    )
        external
        returns (uint);
    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint);
    function claimGas(
        address contractAddress,
        address recipientOfGas,
        uint gasToClaim,
        uint gasSecondsToConsume
    )
        external
        returns (uint);

    function readGasParams(address contractAddress)
        external
        view
        returns (uint etherSeconds, uint etherBalance, uint lastUpdated, GasMode);
}
