// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorage} from "./AppStorage.sol";

library LibSVG {
    function appStorage() internal pure returns (AppStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    // Build the raw SVG image for a token
    function buildRawSVG(uint256 tokenId) internal view returns (string memory) {
        AppStorage storage s = appStorage();
        require(s.owners[tokenId] != address(0), "LibSVG: nonexistent token");

        // If a custom SVG was set, return it directly
        if (bytes(s.collectionSvg).length > 0) {
            return s.collectionSvg;
        }

        // Otherwise generate a default on-chain SVG
        address tokenOwner = s.owners[tokenId];
        return _generateDefaultSvg(
            s.erc721name,
            s.erc721symbol,
            _toHexString(tokenOwner),
            _toString(s.balances[tokenOwner])
        );
    }

    // Build full data-URI token metadata (JSON + embedded SVG)
    function buildTokenURI(uint256 tokenId) internal view returns (string memory) {
        AppStorage storage s = appStorage();
        require(s.owners[tokenId] != address(0), "LibSVG: nonexistent token");

        string memory collectionName = s.erc721name;
        string memory collectionSymbol = s.erc721symbol;
        string memory ownerString = _toHexString(s.owners[tokenId]);
        string memory balanceString = _toString(s.balances[s.owners[tokenId]]);
        string memory image = string(
            abi.encodePacked("data:image/svg+xml;utf8,", buildRawSVG(tokenId))
        );

        return string(
            abi.encodePacked(
                "data:application/json;utf8,",
                "{\"name\":\"",
                collectionName,
                " #",
                _toString(tokenId),
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

    // ── Internal SVG builder ────────────────────────────────────────────────

    function _generateDefaultSvg(
        string memory _collectionName,
        string memory _collectionSymbol,
        string memory _owner,
        string memory _ownerBalance
    ) private pure returns (string memory) {
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
                _collectionName, "</text>",
                _svgBottom(_collectionSymbol, _owner, _ownerBalance)
            )
        );
    }

    function _svgBottom(
        string memory _collectionSymbol,
        string memory _owner,
        string memory _ownerBalance
    ) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "<rect x='40' y='126' width='170' height='36' rx='10' fill='rgb(255,255,255)' fill-opacity='0.18' />",
                "<text x='54' y='150' font-family='Verdana' font-size='18' fill='rgb(245,251,255)'>SYMBOL: ",
                _collectionSymbol, "</text>",
                "<text x='40' y='205' font-family='Courier New' font-size='15' fill='rgb(214,236,255)'>Owner</text>",
                "<text x='40' y='232' font-family='Courier New' font-size='16' fill='rgb(255,255,255)'>",
                _owner, "</text>",
                "<text x='40' y='278' font-family='Verdana' font-size='15' fill='rgb(214,236,255)'>Balance</text>",
                "<text x='40' y='310' font-family='Verdana' font-size='30' font-weight='700' fill='rgb(255,224,138)'>",
                _ownerBalance, "</text>",
                "</svg>"
            )
        );
    }

    // ── String helpers ──────────────────────────────────────────────────────

    function _toString(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) return "0";
        uint256 digits;
        uint256 temp = _value;
        while (temp != 0) { digits++; temp /= 10; }
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

}
