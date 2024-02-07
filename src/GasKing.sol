// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

contract GasKingGame {
    address[] public hillAddresses;

    event HillCreated(uint claimDelay);

    constructor() {
        _createHill(1 hours);
    }

    /// External mutative

    function createHill(uint claimDelay) external {
        _createHill(claimDelay);
    }

    /// External views

    function hillAddressesLength() external view returns (uint) {
        return hillAddresses.length;
    }

    /// Internal

    function _createHill(uint claimDelay) internal {
        Hill hill = new Hill(claimDelay);
        hillAddresses.push(address(hill));
        emit HillCreated(claimDelay);
    }


}

contract Hill {

    uint public immutable claimDelay;

    constructor(uint _claimDelay) {
        claimDelay = _claimDelay;
    }

    /// External mutative

    /// External views

    /// Internal

}
