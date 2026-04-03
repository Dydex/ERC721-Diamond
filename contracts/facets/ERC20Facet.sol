// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorage} from "../libraries/AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IERC20} from "../interfaces/IERC20.sol";

contract ERC20Facet is IERC20 {
    AppStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    function name() external view returns (string memory) {
        return s.erc20Name;
    }

    function symbol() external view returns (string memory) {
        return s.erc20Symbol;
    }

    function decimals() external view returns (uint8) {
        return s.erc20Decimals;
    }

    function totalSupply() external view returns (uint256) {
        return s.erc20TotalSupply;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return s.erc20Balances[_owner];
    }

    function transfer(address _to, uint256 _value) external returns (bool success) {
        require(_to != address(0) && _to != msg.sender, "ERC20: invalid address");
        require(_value > 0, "ERC20: invalid amount");
        require(s.erc20Balances[msg.sender] >= _value, "ERC20: insufficient balance");
        s.erc20Balances[msg.sender] -= _value;
        s.erc20Balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _owner, address _to, uint256 _value) external returns (bool success) {
        require(_to != address(0) && _to != _owner, "ERC20: invalid address");
        require(s.erc20Allowances[_owner][msg.sender] >= _value, "ERC20: insufficient allowance");
        require(s.erc20Balances[_owner] >= _value, "ERC20: insufficient balance");
        s.erc20Allowances[_owner][msg.sender] -= _value;
        s.erc20Balances[_owner] -= _value;
        s.erc20Balances[_to] += _value;
        emit Transfer(_owner, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) external returns (bool success) {
        s.erc20Allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return s.erc20Allowances[_owner][_spender];
    }

    function mint(address _to, uint256 _value) external onlyOwner {
        require(_to != address(0), "ERC20: mint to zero address");
        require(_value > 0, "ERC20: invalid amount");
        s.erc20TotalSupply += _value;
        s.erc20Balances[_to] += _value;
        emit Transfer(address(0), _to, _value);
    }
}
