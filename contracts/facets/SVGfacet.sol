// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorage} from "../libraries/AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibSVG} from "../libraries/LibSVG.sol";

contract SVGFacet {
    AppStorage internal s;

    event SvgUpdated();

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    // Owner sets a custom collection SVG template (stored on-chain)
    function setCollectionSvg(string calldata _svg) external onlyOwner {
        require(bytes(_svg).length > 0, "SVG: empty");
        s.collectionSvg = _svg;
        emit SvgUpdated();
    }

    // Read the raw custom SVG template
    function collectionSvg() external view returns (string memory) {
        return s.collectionSvg;
    }

    // Get the on-chain SVG for a specific token
    function getSVG(uint256 tokenId) external view returns (string memory) {
        return LibSVG.buildRawSVG(tokenId);
    }

    // Get the full data-URI metadata for a specific token
    function getTokenURI(uint256 tokenId) external view returns (string memory) {
        return LibSVG.buildTokenURI(tokenId);
    }
}
