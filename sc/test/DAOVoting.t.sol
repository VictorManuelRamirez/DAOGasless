// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { MinimalForwarder } from "../src/MinimalForwarder.sol";
import { DAOVoting } from "../src/DAOVoting.sol";

contract DAOVotingTest is Test {
    MinimalForwarder internal forwarder;
    DAOVoting internal dao;

    address internal alice = vm.addr(1);
    address internal bob = vm.addr(2);
    address internal carol = vm.addr(3);
    address internal relayer = vm.addr(99);
    address internal recipient = vm.addr(4);

    function setUp() public {
        forwarder = new MinimalForwarder();
        dao = new DAOVoting(address(forwarder));
        vm.deal(alice, 20 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 30 ether);
        vm.deal(relayer, 5 ether);
    }

    function test_FundDAO() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        assertEq(dao.userBalances(alice), 10 ether);
        assertEq(dao.totalDAOBalance(), 10 ether);
        assertEq(dao.getUserBalance(alice), 10 ether);
    }

    function test_Receive() public {
        vm.prank(alice);
        (bool ok,) = address(dao).call{ value: 3 ether }("");
        assertTrue(ok);
        assertEq(dao.userBalances(alice), 3 ether);
    }

    function test_CreateProposal_AmountExceedsBalance() public {
        vm.prank(alice);
        dao.fundDAO{ value: 2 ether }();
        vm.prank(alice);
        vm.expectRevert("Invalid amount");
        dao.createProposal(recipient, 3 ether, block.timestamp + 1 days);
    }

    function test_FundDAO_ZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert("Must send ETH");
        dao.fundDAO{ value: 0 }();
    }

    function test_CreateProposal() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        uint256 deadline = block.timestamp + 1 days;
        vm.prank(alice);
        dao.createProposal(bob, 1 ether, deadline);
        assertEq(dao.proposalCount(), 1);
        DAOVoting.Proposal memory p = dao.getProposal(1);
        assertTrue(p.exists);
        assertEq(p.recipient, bob);
        assertEq(p.amount, 1 ether);
        assertEq(p.deadline, deadline);
    }

    function test_CreateProposal_InsufficientBalance() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(bob);
        dao.fundDAO{ value: 1 ether }();
        vm.prank(bob);
        vm.expectRevert("Insufficient balance to propose");
        dao.createProposal(recipient, 0.5 ether, block.timestamp + 1 days);
    }

    function test_CreateProposal_PastDeadline() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(alice);
        vm.expectRevert("Deadline must be in the future");
        dao.createProposal(bob, 1 ether, block.timestamp);
    }

    function test_CreateProposal_ZeroRecipient() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(alice);
        vm.expectRevert("Invalid recipient");
        dao.createProposal(address(0), 1 ether, block.timestamp + 1 days);
    }

    function test_Vote_For() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(alice);
        dao.createProposal(bob, 1 ether, block.timestamp + 1 days);
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);
        assertTrue(dao.hasVoted(1, alice));
        assertEq(uint256(dao.userVotes(1, alice)), uint256(DAOVoting.VoteType.FOR));
        assertEq(dao.getProposal(1).votesFor, 1);
    }

    function test_Vote_Against() public {
        vm.prank(bob);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(bob);
        dao.createProposal(recipient, 1 ether, block.timestamp + 1 days);
        vm.prank(bob);
        dao.vote(1, DAOVoting.VoteType.AGAINST);
        assertEq(dao.getProposal(1).votesAgainst, 1);
    }

    function test_Vote_Abstain() public {
        vm.prank(carol);
        dao.fundDAO{ value: 30 ether }();
        vm.prank(carol);
        dao.createProposal(recipient, 1 ether, block.timestamp + 1 days);
        vm.prank(carol);
        dao.vote(1, DAOVoting.VoteType.ABSTAIN);
        assertEq(dao.getProposal(1).votesAbstain, 1);
    }

    function test_Vote_ChangeVote() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(alice);
        dao.createProposal(bob, 1 ether, block.timestamp + 1 days);
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);
        assertEq(dao.getProposal(1).votesFor, 1);
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.AGAINST);
        assertEq(dao.getProposal(1).votesFor, 0);
        assertEq(dao.getProposal(1).votesAgainst, 1);
    }

    function test_Vote_AfterDeadline() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        uint256 deadline = block.timestamp + 1 hours;
        vm.prank(alice);
        dao.createProposal(bob, 1 ether, deadline);
        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert("Voting period ended");
        dao.vote(1, DAOVoting.VoteType.FOR);
    }

    function test_Vote_NoBalance() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(alice);
        dao.createProposal(bob, 1 ether, block.timestamp + 1 days);
        vm.prank(bob);
        vm.expectRevert("No balance to vote");
        dao.vote(1, DAOVoting.VoteType.FOR);
    }

    function test_Vote_NonexistentProposal() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(alice);
        vm.expectRevert("Proposal does not exist");
        dao.vote(999, DAOVoting.VoteType.FOR);
    }

    function test_ExecuteProposal() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        uint256 deadline = block.timestamp + 1 days;
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, deadline);
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        uint256 balBefore = recipient.balance;
        vm.warp(deadline + 1 hours + 1);
        dao.executeProposal(1);
        assertEq(recipient.balance, balBefore + 1 ether);
        assertTrue(dao.getProposal(1).executed);
    }

    function test_Execute_BeforeSafetyPeriod() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        uint256 deadline = block.timestamp + 1 days;
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, deadline);
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);

        vm.warp(deadline + 1);
        vm.expectRevert("Safety period not elapsed");
        dao.executeProposal(1);
    }

    function test_Execute_AlreadyExecuted() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        uint256 deadline = block.timestamp + 1 days;
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, deadline);
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);
        vm.warp(deadline + 1 hours + 1);
        dao.executeProposal(1);
        vm.expectRevert("Proposal already executed");
        dao.executeProposal(1);
    }

    function test_Execute_NotApproved() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(bob);
        dao.fundDAO{ value: 5 ether }();
        uint256 deadline = block.timestamp + 1 days;
        vm.prank(alice);
        dao.createProposal(recipient, 1 ether, deadline);
        vm.prank(alice);
        dao.vote(1, DAOVoting.VoteType.FOR);
        vm.prank(bob);
        dao.vote(1, DAOVoting.VoteType.AGAINST);
        vm.warp(deadline + 1 hours + 1);
        vm.expectRevert("Proposal not approved");
        dao.executeProposal(1);
    }

    function test_GaslessVote() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(alice);
        dao.createProposal(bob, 1 ether, block.timestamp + 1 days);

        bytes memory callData = abi.encodeWithSelector(dao.vote.selector, uint256(1), DAOVoting.VoteType.FOR);
        MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
            from: alice,
            to: address(dao),
            value: 0,
            gas: 300_000,
            nonce: forwarder.getNonce(alice),
            data: callData
        });

        bytes32 digest = forwarder.getDigest(req);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(relayer);
        (bool success,) = forwarder.execute(req, signature);
        assertTrue(success);

        assertTrue(dao.hasVoted(1, alice));
        assertEq(uint256(dao.userVotes(1, alice)), uint256(DAOVoting.VoteType.FOR));
        assertEq(dao.getProposal(1).votesFor, 1);
    }

    function test_GaslessVote_InvalidSignature() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(alice);
        dao.createProposal(bob, 1 ether, block.timestamp + 1 days);

        bytes memory callData = abi.encodeWithSelector(dao.vote.selector, uint256(1), DAOVoting.VoteType.FOR);
        MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
            from: alice,
            to: address(dao),
            value: 0,
            gas: 300_000,
            nonce: forwarder.getNonce(alice),
            data: callData
        });

        bytes32 digest = forwarder.getDigest(req);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(relayer);
        vm.expectRevert("MinimalForwarder: invalid signature or nonce");
        forwarder.execute(req, signature);
    }

    function test_GaslessVote_ReplayAttack() public {
        vm.prank(alice);
        dao.fundDAO{ value: 10 ether }();
        vm.prank(alice);
        dao.createProposal(bob, 1 ether, block.timestamp + 1 days);

        bytes memory callData = abi.encodeWithSelector(dao.vote.selector, uint256(1), DAOVoting.VoteType.FOR);
        MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
            from: alice,
            to: address(dao),
            value: 0,
            gas: 300_000,
            nonce: forwarder.getNonce(alice),
            data: callData
        });

        bytes32 digest = forwarder.getDigest(req);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(relayer);
        forwarder.execute(req, signature);

        vm.prank(relayer);
        vm.expectRevert("MinimalForwarder: invalid signature or nonce");
        forwarder.execute(req, signature);
    }
}
