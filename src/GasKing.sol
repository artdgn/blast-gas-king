// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IBlast} from "./IBlast.sol";

abstract contract GasClaimer {
    IBlast public immutable blast;

    constructor(IBlast _blast) {
        blast = _blast;
        _blast.configureClaimableGas(); // set the gas fees to claimable
    }

    function _claimAllGas() internal {
        blast.claimAllGas(address(this), address(this));
    }

    receive() external payable {}
}

contract GasKingGame is GasClaimer {
    address[] public hillAddresses;

    event HillCreated(uint claimDelay, address hill);

    constructor(IBlast _blast) GasClaimer(_blast) {
        createHill(1 hours);
    }

    /// External mutative

    function createHill(uint claimDelay) public {
        address hill = address(new Hill(blast, claimDelay));
        hillAddresses.push(hill);
        emit HillCreated(claimDelay, hill);
    }

    function claimAllGas() public {
        _claimAllGas();
        (bool success, ) = address(msg.sender).call{value: address(this).balance}(""); // so generous
        require(success, "failed");
    }

    /// External views

    function hillAddressesLength() external view returns (uint) {
        return hillAddresses.length;
    }




}

contract Hill is GasClaimer {

    uint public immutable claimDelay;

    constructor(IBlast _blast, uint _claimDelay) GasClaimer(_blast) {
        claimDelay = _claimDelay;
    }

    /// External mutative

    /// External views

    /// Internal

}
