// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { MinimalForwarder } from "../src/MinimalForwarder.sol";

contract MinimalForwarderTest is Test {
    MinimalForwarder internal forwarder;
    address internal alice = vm.addr(1);
    address internal bob = vm.addr(2);

    function setUp() public {
        forwarder = new MinimalForwarder();
    }

    function test_Verify_ValidNonceAndSigner() public view {
        MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
            from: alice,
            to: bob,
            value: 0,
            gas: 100_000,
            nonce: 0,
            data: hex""
        });
        bytes32 digest = forwarder.getDigest(req);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertTrue(forwarder.verify(req, signature));
    }

    function test_Verify_WrongSigner() public view {
        MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
            from: alice,
            to: bob,
            value: 0,
            gas: 100_000,
            nonce: 0,
            data: hex""
        });
        bytes32 digest = forwarder.getDigest(req);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertFalse(forwarder.verify(req, signature));
    }

    function test_Execute_IncrementsNonce() public {
        vm.deal(alice, 1 ether);
        MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
            from: alice,
            to: bob,
            value: 0,
            gas: 100_000,
            nonce: 0,
            data: hex""
        });
        bytes32 digest = forwarder.getDigest(req);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(forwarder.getNonce(alice), 0);
        forwarder.execute(req, signature);
        assertEq(forwarder.getNonce(alice), 1);
    }

    function test_Execute_ReplayReverts() public {
        MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
            from: alice,
            to: bob,
            value: 0,
            gas: 100_000,
            nonce: 0,
            data: hex""
        });
        bytes32 digest = forwarder.getDigest(req);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        forwarder.execute(req, signature);
        vm.expectRevert();
        forwarder.execute(req, signature);
    }
}
