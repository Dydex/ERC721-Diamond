// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct AppStorage {
    
    string name;
   
    string symbol;
   
    mapping(uint256 => address) owners;
   
    mapping(address => uint256) balances;
    
    mapping(uint256 => address) tokenApprovals;
    
    mapping(address => mapping(address => bool)) operatorApprovals;
    
    uint256 totalSupply;
}

library LibAppStorage {
    function appStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}