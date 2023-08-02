// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author  Himanshu Gautam
 * @dev     Beacon for beacon proxy pattern 
 */
contract Beacon is Ownable {
    UpgradeableBeacon immutable beacon;
    address public Implementation;

    constructor(address _Implementation) {
        beacon = new UpgradeableBeacon(_Implementation);
        Implementation = _Implementation;
    }

    /**
     * @notice  To Update new implementation using beacon
     */
    function update(address _Implementation) public onlyOwner {
        beacon.upgradeTo(_Implementation);
        Implementation = _Implementation;
    }

    /**
     * @notice  Return Beacon Implementation address
     */
    function implementation() public view returns (address) {
        return beacon.implementation();
    }
}
