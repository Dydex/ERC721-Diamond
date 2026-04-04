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

    function setCollectionSvg(string calldata _svg) external onlyOwner {
        require(bytes(_svg).length > 0, "SVG: empty");
        s.collectionSvg = _svg;
        emit SvgUpdated();
    }

    function collectionSvg() external view returns (string memory) {
        return s.collectionSvg;
    }


    function getSVG(uint256 tokenId) external view returns (string memory) {
        return LibSVG.buildRawSVG(tokenId);
    }

    function getTokenURI(uint256 tokenId) external view returns (string memory) {
        return LibSVG.buildTokenURI(tokenId);
    }
}
