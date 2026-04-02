// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC721Receiver} from "../interfaces/IERC721Receiver.sol";

contract ERC721Facet is IERC721 {
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    function initERC721(string memory _name, string memory _symbol) external onlyOwner {
        AppStorage storage s = LibAppStorage.appStorage();
        require(bytes(s.name).length == 0 && bytes(s.symbol).length == 0, "ERC721: already initialized");

        s.name = _name;
        s.symbol = _symbol;

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC721).interfaceId] = true;
    }

    function name() external view returns (string memory) {
        return LibAppStorage.appStorage().name;
    }

    function symbol() external view returns (string memory) {
        return LibAppStorage.appStorage().symbol;
    }

    function mint(address _to, uint256 _tokenId) external onlyOwner returns (bool) {
        _mint(_to, _tokenId);
        return true;
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        address tokenOwner = s.owners[_tokenId];
        require(tokenOwner != address(0), "ERC721: invalid token ID");

        string memory collectionName = s.name;
        string memory collectionSymbol = s.symbol;
        string memory ownerString = _toHexString(tokenOwner);
        string memory balanceString = _toString(s.balances[tokenOwner]);
        string memory image = string(
            abi.encodePacked(
                "data:image/svg+xml;utf8,",
                _svgImage(collectionName, collectionSymbol, ownerString, balanceString)
            )
        );

        return string(
            abi.encodePacked(
                "data:application/json;utf8,",
                "{\"name\":\"",
                collectionName,
                " #",
                _toString(_tokenId),
                "\",",
                "\"symbol\":\"",
                collectionSymbol,
                "\",",
                "\"owner\":\"",
                ownerString,
                "\",",
                "\"balance\":\"",
                balanceString,
                "\",",
                "\"image\":\"",
                image,
                "\"}"
            )
        );
    }

    function balanceOf(address _owner) external view override returns (uint256) {
        require(_owner != address(0), "ERC721: address zero is not a valid owner");
        return LibAppStorage.appStorage().balances[_owner];
    }

    function ownerOf(uint256 _tokenId) public view override returns (address) {
        AppStorage storage s = LibAppStorage.appStorage();
        address owner = s.owners[_tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function approve(address _approved, uint256 _tokenId) external payable override {
        AppStorage storage s = LibAppStorage.appStorage();
        address owner = ownerOf(_tokenId);
        require(_approved != owner, "ERC721: approval to current owner");
        require(
            msg.sender == owner || s.operatorApprovals[owner][msg.sender],
            "ERC721: caller is not token owner or approved for all"
        );

        s.tokenApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    function getApproved(uint256 _tokenId) external view override returns (address) {
        AppStorage storage s = LibAppStorage.appStorage();
        require(s.owners[_tokenId] != address(0), "ERC721: invalid token ID");
        return s.tokenApprovals[_tokenId];
    }

    function setApprovalForAll(address _operator, bool _approved) external override {
        require(_operator != msg.sender, "ERC721: approve to caller");
        AppStorage storage s = LibAppStorage.appStorage();
        s.operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _owner, address _operator) external view override returns (bool) {
        return LibAppStorage.appStorage().operatorApprovals[_owner][_operator];
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external payable override {
        _transfer(_from, _to, _tokenId, msg.sender, "");
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable override {
        _transfer(_from, _to, _tokenId, msg.sender, "");
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) external payable override {
        _transfer(_from, _to, _tokenId, msg.sender, _data);
    }

    function _mint(address _to, uint256 _tokenId) internal {
        require(_to != address(0), "ERC721: mint to the zero address");

        AppStorage storage s = LibAppStorage.appStorage();
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
        require(_to != address(0), "ERC721: transfer to the zero address");

        AppStorage storage s = LibAppStorage.appStorage();
        address owner = ownerOf(_tokenId);
        require(owner == _from, "ERC721: transfer from incorrect owner");
        require(_isApprovedOrOwner(_operator, _tokenId), "ERC721: caller is not token owner or approved");

        delete s.tokenApprovals[_tokenId];
        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;

        emit Transfer(_from, _to, _tokenId);

        if (_to.code.length != 0) {
            require(
                IERC721Receiver(_to).onERC721Received(_operator, _from, _tokenId, _data) ==
                    IERC721Receiver.onERC721Received.selector,
                "ERC721: transfer to non ERC721Receiver implementer"
            );
        }
    }

    function _isApprovedOrOwner(address _spender, uint256 _tokenId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        address owner = ownerOf(_tokenId);
        return (
            _spender == owner ||
            s.tokenApprovals[_tokenId] == _spender ||
            s.operatorApprovals[owner][_spender]
        );
    }

    function _toString(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) {
            return "0";
        }

        uint256 digits;
        uint256 temp = _value;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (_value % 10)));
            _value /= 10;
        }

        return string(buffer);
    }

    function _toHexString(address _account) internal pure returns (string memory) {
        bytes20 value = bytes20(_account);
        bytes16 symbols = "0123456789abcdef";
        bytes memory buffer = new bytes(42);
        buffer[0] = "0";
        buffer[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            buffer[2 + i * 2] = symbols[uint8(value[i] >> 4)];
            buffer[3 + i * 2] = symbols[uint8(value[i] & 0x0f)];
        }

        return string(buffer);
    }

    function _svgImage(
        string memory _collectionName,
        string memory _collectionSymbol,
        string memory _owner,
        string memory _ownerBalance
    ) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 600 360'>",
                "<rect width='600' height='360' fill='rgb(8,16,41)' />",
                "<rect y='120' width='600' height='240' fill='rgb(23,162,184)' fill-opacity='0.42' />",
                "<circle cx='520' cy='70' r='140' fill='rgb(255,255,255)' fill-opacity='0.08' />",
                "<circle cx='80' cy='330' r='120' fill='rgb(255,209,102)' fill-opacity='0.16' />",
                "<rect x='20' y='20' width='560' height='320' rx='20' fill='rgb(255,255,255)' fill-opacity='0.10' stroke='rgb(255,255,255)' stroke-opacity='0.35' />",
                "<text x='40' y='58' font-family='Verdana' font-size='14' fill='rgb(215,246,255)' letter-spacing='1.5'>ON-CHAIN ERC721</text>",
                "<text x='40' y='110' font-family='Verdana' font-size='34' font-weight='700' fill='rgb(255,255,255)'>",
                _collectionName,
                "</text>",
                "<rect x='40' y='126' width='170' height='36' rx='10' fill='rgb(255,255,255)' fill-opacity='0.18' />",
                "<text x='54' y='150' font-family='Verdana' font-size='18' fill='rgb(245,251,255)'>SYMBOL: ",
                _collectionSymbol,
                "</text>",
                "<text x='40' y='205' font-family='Courier New' font-size='15' fill='rgb(214,236,255)'>Owner</text>",
                "<text x='40' y='232' font-family='Courier New' font-size='16' fill='rgb(255,255,255)'>",
                _owner,
                "</text>",
                "<text x='40' y='278' font-family='Verdana' font-size='15' fill='rgb(214,236,255)'>Balance</text>",
                "<text x='40' y='310' font-family='Verdana' font-size='30' font-weight='700' fill='rgb(255,224,138)'>",
                _ownerBalance,
                "</text>",
                "</svg>"
            )
        );
    }
}