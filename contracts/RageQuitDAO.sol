// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract RageQuitDAO {
    uint256 public totalShares;
    mapping(address => uint256) public shares;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 amount;
        address payable recipient;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event Joined(address indexed member, uint256 sharesMinted, uint256 ethDeposited);
    event Proposed(uint256 indexed id, address indexed proposer, string description, uint256 amount, address recipient);
    event Voted(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event Executed(uint256 indexed id);
    event RageQuit(address indexed member, uint256 sharesBurned, uint256 ethReturned);

    // Join the DAO by depositing ETH
    function join() external payable {
        require(msg.value > 0, "Must deposit ETH");
        uint256 sharesToMint;

        if (totalShares == 0) {
            sharesToMint = msg.value; // 1 wei = 1 share initially
        } else {
            uint256 currentTreasury = address(this).balance - msg.value;
            sharesToMint = (msg.value * totalShares) / currentTreasury;
        }

        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;

        emit Joined(msg.sender, sharesToMint, msg.value);
    }

    // Create a proposal
    function propose(string calldata description, uint256 amount, address payable recipient) external {
        require(shares[msg.sender] > 0, "Must be a member");
        require(amount <= address(this).balance, "Amount exceeds treasury");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            description: description,
            amount: amount,
            recipient: recipient,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + 3 days,
            executed: false
        });

        emit Proposed(proposalCount, msg.sender, description, amount, recipient);
    }

    // Vote on a proposal
    function vote(uint256 proposalId, bool support) external {
        require(shares[msg.sender] > 0, "Must be a member");
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        
        Proposal storage p = proposals[proposalId];
        require(block.timestamp < p.deadline, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = shares[msg.sender];
        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }

        hasVoted[proposalId][msg.sender] = true;
        emit Voted(proposalId, msg.sender, support, weight);
    }

    // Execute a proposal
    function execute(uint256 proposalId) external {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.deadline, "Voting not ended");
        require(!p.executed, "Already executed");
        require(p.votesFor > p.votesAgainst, "Proposal rejected");
        require(p.amount <= address(this).balance, "Insufficient treasury");

        p.executed = true;
        p.recipient.transfer(p.amount);

        emit Executed(proposalId);
    }

    // Rage quit: burn shares and get proportional ETH back
    function rageQuit(uint256 shareAmount) external {
        require(shareAmount > 0, "Amount must be > 0");
        require(shares[msg.sender] >= shareAmount, "Insufficient shares");

        // Calculate proportional share of the treasury
        uint256 ethToReturn = (shareAmount * address(this).balance) / totalShares;

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;

        payable(msg.sender).transfer(ethToReturn);

        emit RageQuit(msg.sender, shareAmount, ethToReturn);
    }

    // Helper to get all proposals for the frontend
    function getAllProposals() external view returns (Proposal[] memory) {
        Proposal[] memory allProposals = new Proposal[](proposalCount);
        for (uint256 i = 1; i <= proposalCount; i++) {
            allProposals[i - 1] = proposals[i];
        }
        return allProposals;
    }

    // Fallback to receive ETH directly into the treasury
    receive() external payable {}
}
