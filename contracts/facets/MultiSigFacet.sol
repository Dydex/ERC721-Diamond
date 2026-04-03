// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorage, MultiSigTransaction} from "../libraries/AppStorage.sol";

contract MultiSigFacet {
    AppStorage internal s;

    // ── Events ──────────────────────────────────────────────────────────────
    event MultiSigInitialized(address[] signers, uint256 quorum);
    event TransactionSubmitted(uint256 indexed txId, address indexed to, uint256 value, bytes data);
    event TransactionConfirmed(uint256 indexed txId, address indexed signer);
    event ConfirmationRevoked(uint256 indexed txId, address indexed signer);
    event TransactionExecuted(uint256 indexed txId);
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event QuorumChanged(uint256 newQuorum);

    // ── Modifiers ───────────────────────────────────────────────────────────

    modifier onlySigner() {
        require(s.msIsSigner[msg.sender], "MultiSig: not a signer");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "MultiSig: must execute via multisig");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < s.msTransactions.length, "MultiSig: tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!s.msTransactions[_txId].executed, "MultiSig: tx already executed");
        _;
    }

    // ── Initialization ──────────────────────────────────────────────────────

    // One-time multisig setup
    function initializeMultiSig(address[] calldata _signers, uint256 _quorum) external {
        require(!s.msInitialized, "MultiSig: already initialized");
        require(_signers.length > 0, "MultiSig: no signers");
        require(_quorum > 0 && _quorum <= _signers.length, "MultiSig: invalid quorum");

        for (uint256 i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            require(signer != address(0), "MultiSig: zero address signer");
            require(!s.msIsSigner[signer], "MultiSig: duplicate signer");
            s.msIsSigner[signer] = true;
            s.msSigners.push(signer);
        }

        s.msQuorum = _quorum;
        s.msInitialized = true;

        emit MultiSigInitialized(_signers, _quorum);
    }

    // ── Core Functions ──────────────────────────────────────────────────────

    // Submit a new transaction proposal
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlySigner returns (uint256 txId) {
        require(_to != address(0), "MultiSig: zero address target");

        txId = s.msTransactions.length;
        s.msTransactions.push(MultiSigTransaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        }));

        emit TransactionSubmitted(txId, _to, _value, _data);
    }

    // Confirm a pending transaction
    function confirmTransaction(uint256 _txId)
        external
        onlySigner
        txExists(_txId)
        notExecuted(_txId)
    {
        require(!s.msConfirmations[_txId][msg.sender], "MultiSig: already confirmed");

        s.msConfirmations[_txId][msg.sender] = true;
        s.msTransactions[_txId].confirmationCount += 1;

        emit TransactionConfirmed(_txId, msg.sender);
    }

    // Revoke a previous confirmation
    function revokeConfirmation(uint256 _txId)
        external
        onlySigner
        txExists(_txId)
        notExecuted(_txId)
    {
        require(s.msConfirmations[_txId][msg.sender], "MultiSig: not confirmed");

        s.msConfirmations[_txId][msg.sender] = false;
        s.msTransactions[_txId].confirmationCount -= 1;

        emit ConfirmationRevoked(_txId, msg.sender);
    }

    // Execute a transaction once quorum is reached
    function executeTransaction(uint256 _txId)
        external
        onlySigner
        txExists(_txId)
        notExecuted(_txId)
    {
        MultiSigTransaction storage txn = s.msTransactions[_txId];
        require(txn.confirmationCount >= s.msQuorum, "MultiSig: quorum not reached");

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "MultiSig: execution failed");

        emit TransactionExecuted(_txId);
    }

    // ── Governance (only callable via multisig execution) ───────────────────

    // Add a new signer — must be executed through the multisig
    function addSigner(address _signer) external onlySelf {
        require(_signer != address(0), "MultiSig: zero address");
        require(!s.msIsSigner[_signer], "MultiSig: already a signer");

        s.msIsSigner[_signer] = true;
        s.msSigners.push(_signer);

        emit SignerAdded(_signer);
    }

    // Remove a signer — must be executed through the multisig
    function removeSigner(address _signer) external onlySelf {
        require(s.msIsSigner[_signer], "MultiSig: not a signer");
        require(s.msSigners.length - 1 >= s.msQuorum, "MultiSig: would break quorum");

        s.msIsSigner[_signer] = false;

        // Swap-and-pop to remove from array
        for (uint256 i = 0; i < s.msSigners.length; i++) {
            if (s.msSigners[i] == _signer) {
                s.msSigners[i] = s.msSigners[s.msSigners.length - 1];
                s.msSigners.pop();
                break;
            }
        }

        emit SignerRemoved(_signer);
    }

    // Change the quorum — must be executed through the multisig
    function changeQuorum(uint256 _newQuorum) external onlySelf {
        require(_newQuorum > 0 && _newQuorum <= s.msSigners.length, "MultiSig: invalid quorum");
        s.msQuorum = _newQuorum;
        emit QuorumChanged(_newQuorum);
    }

    // ── View Functions ──────────────────────────────────────────────────────

    function getTransaction(uint256 _txId)
        external
        view
        txExists(_txId)
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmationCount
        )
    {
        MultiSigTransaction storage txn = s.msTransactions[_txId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmationCount);
    }

    function getTransactionCount() external view returns (uint256) {
        return s.msTransactions.length;
    }

    function getSigners() external view returns (address[] memory) {
        return s.msSigners;
    }

    function getQuorum() external view returns (uint256) {
        return s.msQuorum;
    }

    function isConfirmed(uint256 _txId, address _signer) external view returns (bool) {
        return s.msConfirmations[_txId][_signer];
    }

    function isSigner(address _account) external view returns (bool) {
        return s.msIsSigner[_account];
    }
}
