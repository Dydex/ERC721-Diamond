// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct StakePosition {
    address staker;
    uint256 stakedAt;
    uint256 unlockTime;
    bool rewardClaimed;
}

struct MultiSigTransaction {
    address to;
    uint256 value;
    bytes data;
    bool executed;
    uint256 confirmationCount;
}

struct Listing {
    address seller;
    uint256 price;
    bool active;
}

struct BorrowPosition {
    address originalOwner;
    address borrower;
    uint256 collateralAmount;
    uint256 returnDeadline;
}

struct AppStorage {
    // ERC721
    string erc721name;
    string erc721symbol;
    mapping(uint256 => address) owners;
    mapping(address => uint256) balances;
    mapping(uint256 => address) tokenApprovals;
    mapping(address => mapping(address => bool)) operatorApprovals;
    uint256 totalSupply;

    // ERC20
    string erc20Name;
    string erc20Symbol;
    uint8 erc20Decimals;
    uint256 erc20TotalSupply;
    mapping(address => uint256) erc20Balances;
    mapping(address => mapping(address => uint256)) erc20Allowances;

    // Staking
    mapping(uint256 => StakePosition) stakes;
    uint256 stakeLockPeriod;
    uint256 stakeRewardAmount;

    // SVG
    string collectionSvg;

    // Multisig
    bool msInitialized;
    address[] msSigners;
    mapping(address => bool) msIsSigner;
    uint256 msQuorum;
    MultiSigTransaction[] msTransactions;
    mapping(uint256 => mapping(address => bool)) msConfirmations;

    // Marketplace
    mapping(uint256 => Listing) listings;

    // ERC721 Borrower
    uint256 borrowCollateralFee;
    uint256 borrowRepaymentPeriod;
    mapping(uint256 => BorrowPosition) borrows;
}
