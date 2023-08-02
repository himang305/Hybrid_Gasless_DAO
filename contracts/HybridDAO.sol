// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "hardhat/console.sol";

/**
 * @author  Himanshu Gautam
 * @title   HybridDAO for Asset Tokenisation
 * @dev     Uses feature of Openzepplin DAO + Gnosis MultiSig wallet with offchain signing using ERC-712
 */
contract HybridDAO is Initializable, ERC20Upgradeable {
    // Max Supply of asset fractionalised token with decimal 18
    uint public maxSupply;
    // Votes required to execute prpoposal
    uint public executionThreshold;
    // Votes required to create proposal
    uint public proposalThreshold;
    // Voting period for a proposal
    uint public votePeriod;

    // solhint-disable var-name-mixedcase
    struct ProposalStr {
        // --- start retyped from Timers.BlockNumber at offset 0x00 ---
        uint64 voteStart;
        address proposer;
        bytes4 __gap_unused0;
        // --- start retyped from Timers.BlockNumber at offset 0x20 ---
        uint64 voteEnd;
        bytes24 __gap_unused1;
        // --- Remaining fields starting at offset 0x40 ---------------
        bool executed;
        bool canceled;
    }

    // Vote Struct to store total votes alloted to proposal
    // hasVoted mapping to store users who voted
    // voteCount mapping to store users votes at the time of voting
    struct VoteStr {
        uint256 Votes;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voteCount;
    }

    /// @custom:oz-retyped-from mapping(uint256 => ProposalStr)
    mapping(uint256 => ProposalStr) public Proposals;
    mapping(uint256 => VoteStr) private ProposalVotes;

    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );
    event DaoUpdate(
        uint MaxSupply,
        uint ExecutionThreshold,
        uint ProposalThreshold,
        uint VotePeriod
    );
    event VoteProposal(uint256 proposalId, address voter);
    event VoteProposalBySig(uint256 proposalId, address voter, address sender);
    event ExecuteProposal(uint256 proposalId, address executor);
    event CancelProposal(uint256 proposalId);

    /**
     * @dev  Modifier to allow only DAO contract to call its function using proposals
     */
    modifier OnlySelf() {
        require(msg.sender == address(this), "Invalid sender");
        _;
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev     Initialization of asset token details and DAO parameters
     * @param   _name  Token name.
     * @param   _symbol  Token symbol
     * @param   _maxSupply  Token max supply
     * @param   _owners  Initial Members of DAO
     * @param   _votes   Initial tokens to members
     * @param   _executionThreshold  Votes approval required to execute proposal
     * @param   _proposalThreshold  Votes requried to create proposal
     * @param   _votePeriod  Voting Period in seconds.
     */
    function initialize(
        string calldata _name,
        string calldata _symbol,
        uint256 _maxSupply,
        address[] calldata _owners,
        uint256[] calldata _votes,
        uint256 _executionThreshold,
        uint256 _proposalThreshold,
        uint256 _votePeriod
    ) public initializer {
        __ERC20_init(_name, _symbol);
        maxSupply = _maxSupply;
        executionThreshold = _executionThreshold;
        proposalThreshold = _proposalThreshold;
        votePeriod = _votePeriod;

        for (uint256 i; i < _owners.length; i++) {
            require(
                totalSupply() + _votes[i] < _maxSupply,
                "maxSupply crossed"
            );
            _mint(_owners[i], _votes[i]);
        }
    }

    /**
     * @dev     Modify DAO parameters
     * @param   _maxSupply  Max Supply of Asset tokens
     * @param   _executionThreshold  Execution votes threshold 
     * @param   _proposalThreshold  Voted required to propose 
     * @param   _votePeriod  Voting Period after proposal creation
     */
    function modifyDAO(
        uint256 _maxSupply,
        uint256 _executionThreshold,
        uint256 _proposalThreshold,
        uint256 _votePeriod
    ) external OnlySelf {
        maxSupply = _maxSupply;
        executionThreshold = _executionThreshold;
        proposalThreshold = _proposalThreshold;
        votePeriod = _votePeriod;
        // event:
    }

    /**
     * @dev     Mints asset tokens to different users who become member of DAO only by proposal.
     * @param   _owners  Array to user's address to receive tokens.
     * @param   _votes   Amount of token to be minted in each addresses.
     */
    function mint(
        address[] calldata _owners,
        uint256[] calldata _votes
    ) public OnlySelf {
        for (uint256 i; i < _owners.length; i++) {
            require(totalSupply() + _votes[i] < maxSupply, "maxSupply crossed");
            _mint(_owners[i], _votes[i]);
        }
    }

    /**
     * @dev     Create Proposal consisting of multiple txn to be executed on different destinations.
     * @param   targets  Destination addresses
     * @param   values   Values to be send to destinations
     * @param   calldatas  Function signatures with argument to be executed on destinations
     * @param   description  Description for the proposal
     * @return  uint256  Proposal ID
     */
    function createProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        address proposer = msg.sender;
        require(
            balanceOf(proposer) >= proposalThreshold,
            "invalid proposalThreshold"
        );

        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        require(targets.length == values.length, "invalid proposal length");
        require(targets.length == calldatas.length, "invalid proposal length");
        require(targets.length > 0, "empty proposal");
        require(
            Proposals[proposalId].voteStart == 0,
            "proposal already exists"
        );
        uint64 start = SafeCast.toUint64(block.timestamp);
        uint64 deadline = SafeCast.toUint64(block.timestamp + votePeriod);

        Proposals[proposalId] = ProposalStr({
            proposer: proposer,
            voteStart: start,
            voteEnd: deadline,
            executed: false,
            canceled: false,
            __gap_unused0: 0,
            __gap_unused1: 0
        });

        emit ProposalCreated(
            proposalId,
            proposer,
            targets,
            values,
            calldatas,
            start,
            deadline,
            description
        );

        return proposalId;
    }

    /**
     * @dev     Execute Proposal after execution threshold is reached
     * @param   targets  Destination addresses
     * @param   values   Values to be send to destinations
     * @param   calldatas  Function signatures with argument to be executed on destinations
     * @param   descriptionHash  Description Hash
     * @return  proposalId  Proposal ID
     */
    function executeProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable returns (uint256 proposalId) {
        proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        if (
            checkProposalStatus(proposalId) &&
            ProposalVotes[proposalId].Votes >= executionThreshold
        ) {
            Proposals[proposalId].executed = true;
            emit ExecuteProposal(proposalId, msg.sender);
            _execute(targets, values, calldatas);
        }
    }

    /**
     * @dev     Cancel pending proposal only proposal allowed
     * @param   proposalId  Proposal ID
     */
    function cancelProposal(uint256 proposalId) external {
        require(msg.sender == Proposals[proposalId].proposer, "only proposer");
        require(checkProposalStatus(proposalId), "invalid proposal");
        Proposals[proposalId].canceled = true;
        emit CancelProposal(proposalId);
    }

    /**
     * @dev     Vote on proposal by DAO member
     * @param   proposalId  Proposal ID 
     */
    function voteProposal(uint256 proposalId) external {
        address sender = msg.sender;
        uint256 userVotes = balanceOf(sender);

        require(checkProposalStatus(proposalId), "invalid proposal");
        require(
            Proposals[proposalId].voteEnd > block.timestamp,
            "invalid voting period"
        );

        VoteStr storage votestr = ProposalVotes[proposalId];
        require(!votestr.hasVoted[sender], "already voted");

        votestr.Votes += userVotes;
        votestr.hasVoted[sender] = true;
        votestr.voteCount[sender] = userVotes;

        emit VoteProposal(proposalId, sender);
    }

    /**
     * @dev     Hash the proposal txn data and returns a proposal id.
     * @param   targets  Destinaiton addresses.
     * @param   values   Values to be send to destination addresses.
     * @param   calldatas  Hashed function signatures with arguments array.
     * @param   descriptionHash  Hash of proposal description.
     * @return  uint256  Proposal ID
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(targets, values, calldatas, descriptionHash)
                )
            );
    }

    /**
     * @dev     Check proposal is in pending state not executed or cancelled.
     * @param   proposalId  Id of proposal.
     * @return  bool  True for pending proposal
     */
    function checkProposalStatus(
        uint256 proposalId
    ) public view returns (bool) {
        ProposalStr memory proposal = Proposals[proposalId];
        if (proposal.executed || proposal.canceled || proposal.voteStart == 0) {
            return false;
        }
        return true;
    }

    /**
     * @dev     Internal Execute funtion perform bulk execution of proposed txn.
     * @param   targets  Destination addresses array
     * @param   values   Values array to be send to destination addresses.
     * @param   calldatas  Hashed function signatures with arguments array.
     */
    function _execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) internal {
        for (uint i; i < targets.length; ++i) {
            (bool success, bytes memory result) = targets[i].call{
                value: values[i]
            }(calldatas[i]);
            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
        }
    }

    /**
     * @dev     Allow Gas less txn by 3rd party wallet with signed msg from DAO members.
     * @param   _proposalId Proposal ID to vote for.
     * @param   signatures  Concat Signatures of multiple DAO members
     */
    function castMultipleVoteBySignature(
        uint256 _proposalId,
        bytes memory signatures
    ) external returns (uint i) {
        require(checkProposalStatus(_proposalId), "invalid proposal");
        require(
            Proposals[_proposalId].voteEnd > block.timestamp,
            "invalid voting period"
        );
        VoteStr storage votestr = ProposalVotes[_proposalId];
        address sender = msg.sender;

        bytes32 messageHash = getMessageHashed(
            block.chainid,
            address(this),
            _proposalId
        );
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        uint sigCount = signatures.length / 65;
        require(sigCount > 0, "Invalid_Sig");

        for (i; i < sigCount; i++) {
            (uint8 v, bytes32 r, bytes32 s) = signatureSplit(signatures, i);
            address voter = ecrecover(ethSignedMessageHash, v, r, s);
            uint256 userVotes = balanceOf(voter);

            if (userVotes > 0 && !votestr.hasVoted[voter]) {
                votestr.Votes += userVotes;
                votestr.hasVoted[voter] = true;
                votestr.voteCount[voter] = userVotes;
                emit VoteProposalBySig(_proposalId, voter, sender);
            }
        }
    }

    /**
     * @notice Computes a hash of a proposal message for signature verification.
     * @dev This function calculates the hash of a proposal message using the provided parameters.
     * @param _chain The chain ID of the network to avoid signature replay 
     * @param _dao The address of the DAO contract to avoid signature replay 
     * @param _proposalId The unique identifier of the proposal.
     * @return bytes32 The computed hash of the proposal message.
     */
    function getMessageHashed(
        uint _chain,
        address _dao,
        uint256 _proposalId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_chain, _dao, _proposalId));
    }

    /**
     * @notice Computes the Signed Message hash for a given message hash.
     * @dev This function prepares the message hash for Signed Message verification.
     * @param _messageHash The hash of the original message.
     * @return bytes32 The computed Signed Message hash.
     */
    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    /**
     * @notice Splits a concatenated signature into its components.
     * @dev This function extracts the components (v, r, and s) of a signature from concatenated bytes.
     * @param signatures The concatenated bytes containing one or more signatures.
     * @param pos The position of the signature to extract (0-based index).
     * @return v uint8 The recovery id (v) component of the signature.
     * @return r bytes32 The r component of the signature.
     * @return s bytes32 The s component of the signature.
     */
    function signatureSplit(
        bytes memory signatures,
        uint256 pos
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
        }
    }
}
