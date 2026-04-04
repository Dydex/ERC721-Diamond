// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorage, Traits, ReqData} from "../libraries/AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibSVG} from "../libraries/LibSVG.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC721Receiver} from "../interfaces/IERC721Receiver.sol";
import './VRFfacet.sol';

contract ERC721Facet {
    AppStorage internal s;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    // Metadata 

    function erc721name() external view returns (string memory) {
        return s.erc721name;
    }

    function erc721symbol() external view returns (string memory) {
        return s.erc721symbol;
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        require(s.owners[_tokenId] != address(0), "ERC721: invalid token ID");
        return LibSVG.buildTokenURI(_tokenId);
    }

     function getTokenData(uint256 _tokenId) public view returns (Traits memory) {
        return resolveTraits(_tokenId);
    }

    function erc721totalSupply() external view returns (uint256) {
        return s.totalSupply;
    }

    function erc721mint(address _to) external onlyOwner returns (bool) {
        uint256 _tokenId = s.nextTokenId;
        _mint(_to, _tokenId);
        return true;
    }

    //  ERC721 Standard 

    function erc721balanceOf(address _owner) external view returns (uint256) {
        require(_owner != address(0), "ERC721: zero address query");
        return s.balances[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = s.owners[_tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function erc721approve(address _approved, uint256 _tokenId) external payable {
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

    function erc721transferFrom(address _from, address _to, uint256 _tokenId) external payable {
        _transfer(_from, _to, _tokenId, msg.sender, "");
    }

    function erc721safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable {
        _transfer(_from, _to, _tokenId, msg.sender, "");
    }

    function erc721safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) external payable {
        _transfer(_from, _to, _tokenId, msg.sender, _data);
    }

    //  Internal function

    function _mint(address _to, uint256 _tokenId) internal {
        require(_to != address(0), "ERC721: mint to zero address");
        require(s.owners[_tokenId] == address(0), "ERC721: token already minted");

        s.owners[_tokenId] = _to;
        s.balances[_to] += 1;
        s.totalSupply += 1;
        VRFFacet(address(this)).getWords(_tokenId);
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

    function resolveTraits(uint256 _tokenId) internal view returns(Traits memory t) {
        //check that the tokenId has a valid randWord/s
        uint256 requestId = s.nftTraits[_tokenId].requestId;
        t.requestId = requestId;

        //check that it is fulfilled
        if(s.requests[requestId].fulfilled) {
            uint256[] memory randW = new uint256[](2);
            randW[0] = s.requests[requestId].randomWords[0];
            randW[1] = s.requests[requestId].randomWords[1];

            //resolve traits
            t.attack = uint16(randW[0]);
            t.defense = 0xffff & uint16((randW[0] >> 10));
            t.mage = (randW[1] % 2) == 0 ? false : true;
        
        }
        return t ;
    }

function setReqData(ReqData memory r) public {
    LibDiamond.enforceIsContractOwner();
    s.reqData = r;
}
}
