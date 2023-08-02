// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import "./Beacon.sol";
import "./HybridDAO.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author  Himanshu Gautam
 * @title   Hybrid DAO Factory Contract
 * @dev     Uses Beacon Proxy Upgradation Pattern
 */
contract DaoFactory is Ownable {
    mapping(address => address[]) public daoMap;

    Beacon immutable DaoBeacon;

    event DaoCreated(address indexed creator, address indexed dao);

    constructor(address _dao) {
        DaoBeacon = new Beacon(_dao);
    }

    /**
     * @dev     Create a Hybrid DAO 
     * @param   _name  Asset Token name
     * @param   _symbol  Asset Token symbol
     * @param   _maxSupply  Asset token max supply
     * @param   _owners  Initial Members of DAO
     * @param   _votes   Initial tokens to members
     * @param   _executionThreshold  Votes approval required to execute proposal
     * @param   _proposalThreshold  Votes requried to create proposal
     * @param   _votePeriod  Voting Period in seconds.
     */
    function createDao(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        address[] memory _owners,
        uint256[] memory _votes,
        uint256 _executionThreshold,
        uint256 _proposalThreshold,
        uint256 _votePeriod
    ) external onlyOwner{
        BeaconProxy proxy = new BeaconProxy(
            address(DaoBeacon),
            abi.encodeWithSelector(
                HybridDAO(payable(address(0))).initialize.selector,
                _name,
                _symbol,
                _maxSupply,
                _owners,
                _votes,
                _executionThreshold,
                _proposalThreshold,
                _votePeriod
            )
        );
        daoMap[msg.sender].push(address(proxy));
        emit DaoCreated(msg.sender, address(proxy));
    }

    /**
     * @dev     Get beacon implementation address
     */
    function getDaoImplementation() public view returns (address) {
        return DaoBeacon.implementation();
    }

    /**
     * @dev     Get Beacon Address
     */
    function getDaoBeacon() public view returns (address) {
        return address(DaoBeacon);
    }

    /**
     * @dev     Get DAO create by user address
     */
    function getUserDao(address _user) public view returns (address[] memory) {
        return daoMap[_user];
    }
}
