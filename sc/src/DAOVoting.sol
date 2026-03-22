// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC2771Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/// @title DAOVoting — ETH-weighted voting with optional gasless calls via trusted forwarder
contract DAOVoting is ERC2771Context, ReentrancyGuard {
    enum VoteType {
        FOR,
        AGAINST,
        ABSTAIN
    }

    struct Proposal {
        uint256 id;
        address recipient;
        uint256 amount;
        uint256 deadline;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votesAbstain;
        bool executed;
        bool exists;
    }

    uint256 public proposalCount;
    uint256 public totalDAOBalance;
    uint256 public constant SAFETY_PERIOD = 1 hours;
    uint256 public constant MIN_BALANCE_PCT = 10;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public userBalances;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => VoteType)) public userVotes;

    event FundsDeposited(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address recipient, uint256 amount, uint256 deadline);
    event VoteCast(uint256 indexed proposalId, address indexed voter, VoteType voteType);
    event VoteChanged(uint256 indexed proposalId, address indexed voter, VoteType oldVote, VoteType newVote);
    event ProposalExecuted(uint256 indexed proposalId, address recipient, uint256 amount);

    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {}

    function _msgSender() internal view override returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    modifier proposalExists(uint256 id) {
        require(proposals[id].exists, "Proposal does not exist");
        _;
    }

    modifier proposalNotExecuted(uint256 id) {
        require(!proposals[id].executed, "Proposal already executed");
        _;
    }

    modifier proposalActive(uint256 id) {
        require(block.timestamp <= proposals[id].deadline, "Voting period ended");
        _;
    }

    receive() external payable {
        _deposit();
    }

    function fundDAO() external payable {
        _deposit();
    }

    function _deposit() internal {
        require(msg.value > 0, "Must send ETH");
        userBalances[_msgSender()] += msg.value;
        totalDAOBalance += msg.value;
        emit FundsDeposited(_msgSender(), msg.value);
    }

    function createProposal(address recipient, uint256 amount, uint256 deadline) external {
        require(userBalances[_msgSender()] * 100 >= totalDAOBalance * MIN_BALANCE_PCT, "Insufficient balance to propose");
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0 && amount <= address(this).balance, "Invalid amount");
        require(deadline > block.timestamp, "Deadline must be in the future");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            recipient: recipient,
            amount: amount,
            deadline: deadline,
            votesFor: 0,
            votesAgainst: 0,
            votesAbstain: 0,
            executed: false,
            exists: true
        });
        emit ProposalCreated(proposalCount, recipient, amount, deadline);
    }

    function vote(uint256 proposalId, VoteType voteType)
        external
        proposalExists(proposalId)
        proposalActive(proposalId)
    {
        require(userBalances[_msgSender()] > 0, "No balance to vote");
        address voter = _msgSender();

        if (hasVoted[proposalId][voter]) {
            VoteType oldVote = userVotes[proposalId][voter];
            if (oldVote == VoteType.FOR) proposals[proposalId].votesFor--;
            else if (oldVote == VoteType.AGAINST) proposals[proposalId].votesAgainst--;
            else proposals[proposalId].votesAbstain--;

            emit VoteChanged(proposalId, voter, oldVote, voteType);
        } else {
            hasVoted[proposalId][voter] = true;
            emit VoteCast(proposalId, voter, voteType);
        }

        if (voteType == VoteType.FOR) proposals[proposalId].votesFor++;
        else if (voteType == VoteType.AGAINST) proposals[proposalId].votesAgainst++;
        else proposals[proposalId].votesAbstain++;

        userVotes[proposalId][voter] = voteType;
    }

    function executeProposal(uint256 proposalId)
        external
        nonReentrant
        proposalExists(proposalId)
        proposalNotExecuted(proposalId)
    {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp > p.deadline + SAFETY_PERIOD, "Safety period not elapsed");
        require(p.votesFor > p.votesAgainst, "Proposal not approved");
        require(address(this).balance >= p.amount, "Insufficient DAO balance");

        p.executed = true;
        totalDAOBalance -= p.amount;

        (bool success,) = p.recipient.call{ value: p.amount }("");
        require(success, "Transfer failed");

        emit ProposalExecuted(proposalId, p.recipient, p.amount);
    }

    function getProposal(uint256 proposalId) external view proposalExists(proposalId) returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getUserBalance(address user) external view returns (uint256) {
        return userBalances[user];
    }
}
