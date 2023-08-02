# Hybrid Asset Tokenisation DAO with GasLess Voting Option

This project demonstrates a hybrid DAO + MultiSig platform that allows Users to create DAO for asset tokenisation.
    It uses Beacon Proxy Pattern to create proxies of these DAO.
    Each DAO governed through a fractionalised asset into token with its members. ( 1 Token = 1 Vote )
    Members can create proposals with multicall feature to get votes of members on it.
    Other members can vote by self or use offchain signing to allow for gas less voting.
    Also gas less execution is possible.

Features:
    Beacon Procy Pattern 
    Multi Call Proposals
    Off Chain signing by members to allow for gas less operation of DAO
    Proposal ID based on their data hash to avoid storing proposal onchain

Practical Usage:
    Asset Tokenisation DAO: Commodity / Real Estate / Company Equity Fractionalisation and Governace

To run the project:
    1. clone the repo
    2. npm install
    3. npx hardhat test


Improvements:
    Multiple option to Vote on proposals like Yes, No or Abstain from Vote
          Also allow for quorum threshold on proposals
    Whole platform GasLess : Modify Proposal function to be gas less using signature  
          since Voting and Execution are already gas less
    Proposals can be executed automatically on reaching threshold
    Option to cancel their Vote by members.

Reference: Gnosis MultiSig, Openzepplin DAO
  
