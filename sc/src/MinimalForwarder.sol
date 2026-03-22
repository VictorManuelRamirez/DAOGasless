// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title MinimalForwarder — EIP-2771 compatible forwarder (EIP-712 signed requests)
contract MinimalForwarder is EIP712 {
    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }

    bytes32 private constant _TYPEHASH = keccak256(
        "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)"
    );

    mapping(address => uint256) private _nonces;

    event MetaTransactionExecuted(address indexed from, address indexed to, bytes data);

    constructor() EIP712("MinimalForwarder", "1") {}

    function getNonce(address from) external view returns (uint256) {
        return _nonces[from];
    }

    function getDigest(ForwardRequest calldata req) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                _TYPEHASH,
                req.from,
                req.to,
                req.value,
                req.gas,
                req.nonce,
                keccak256(req.data)
            )
        );
        return _hashTypedDataV4(structHash);
    }

    function verify(ForwardRequest calldata req, bytes calldata signature) public view returns (bool) {
        bytes32 digest = getDigest(req);
        address signer = ECDSA.recover(digest, signature);
        return _nonces[req.from] == req.nonce && signer == req.from;
    }

    function execute(ForwardRequest calldata req, bytes calldata signature)
        public
        payable
        returns (bool success, bytes memory returndata)
    {
        require(verify(req, signature), "MinimalForwarder: invalid signature or nonce");
        _nonces[req.from]++;

        (success, returndata) = req.to.call{ value: req.value, gas: req.gas }(abi.encodePacked(req.data, req.from));

        emit MetaTransactionExecuted(req.from, req.to, req.data);
    }
}
