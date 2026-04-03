// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorage} from "../libraries/AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibSVG} from "../libraries/LibSVG.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC721Receiver} from "../interfaces/IERC721Receiver.sol";

contract ERC721Facet is IERC721 {
    AppStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    // ── Metadata ────────────────────────────────────────────────────────────

    function name() external view returns (string memory) {
        return s.erc721name;
    }

    function symbol() external view returns (string memory) {
        return s.erc721symbol;
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        require(s.owners[_tokenId] != address(0), "ERC721: invalid token ID");
        return LibSVG.buildTokenURI(_tokenId);
    }

    function totalSupply() external view returns (uint256) {
        return s.totalSupply;
    }

    // ── Mint ────────────────────────────────────────────────────────────────

    function mint(address _to, uint256 _tokenId) external onlyOwner returns (bool) {
        _mint(_to, _tokenId);
        return true;
    }

    // ── ERC721 Standard ─────────────────────────────────────────────────────

    function balanceOf(address _owner) external view returns (uint256) {
        require(_owner != address(0), "ERC721: zero address query");
        return s.balances[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = s.owners[_tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function approve(address _approved, uint256 _tokenId) external payable {
        address owner = ownerOf(_tokenId);
        require(_approved != owner, "ERC721: approval to current owner");
        require(
            msg.sender == owner || s.operatorApprovals[owner][msg.sender],
            "ERC721: not token owner or approved for all"
        );
        s.tokenApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    function getApproved(uint256 _tokenId) external view returns (address) {
        require(s.owners[_tokenId] != address(0), "ERC721: invalid token ID");
        return s.tokenApprovals[_tokenId];
    }

    function setApprovalForAll(address _operator, bool _approved) external {
        require(_operator != msg.sender, "ERC721: approve to caller");
        s.operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return s.operatorApprovals[_owner][_operator];
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external payable {
        _transfer(_from, _to, _tokenId, msg.sender, "");
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable {
        _transfer(_from, _to, _tokenId, msg.sender, "");
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) external payable {
        _transfer(_from, _to, _tokenId, msg.sender, _data);
    }

    // ── Internal ────────────────────────────────────────────────────────────

    function _mint(address _to, uint256 _tokenId) internal {
        require(_to != address(0), "ERC721: mint to zero address");
        require(s.owners[_tokenId] == address(0), "ERC721: token already minted");
        s.owners[_tokenId] = _to;
        s.balances[_to] += 1;
        s.totalSupply += 1;
        emit Transfer(address(0), _to, _tokenId);
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _tokenId,
        address _operator,
        bytes memory _data
    ) internal {
        require(_to != address(0), "ERC721: transfer to zero address");
        address owner = ownerOf(_tokenId);
        require(owner == _from, "ERC721: transfer from incorrect owner");
        require(_isApprovedOrOwner(_operator, _tokenId), "ERC721: not owner or approved");

        delete s.tokenApprovals[_tokenId];
        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;

        emit Transfer(_from, _to, _tokenId);

        if (_to.code.length != 0) {
            require(
                IERC721Receiver(_to).onERC721Received(_operator, _from, _tokenId, _data) ==
                    IERC721Receiver.onERC721Received.selector,
                "ERC721: transfer to non ERC721Receiver"
            );
        }
    }

    function _isApprovedOrOwner(address _spender, uint256 _tokenId) internal view returns (bool) {
        address owner = ownerOf(_tokenId);
        return (
            _spender == owner ||
            s.tokenApprovals[_tokenId] == _spender ||
            s.operatorApprovals[owner][_spender]
        );
    }
}
