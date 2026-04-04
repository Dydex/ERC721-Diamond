// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {ERC721Facet} from "../contracts/facets/ERC721facet.sol";
import {SVGFacet} from "../contracts/facets/SVGfacet.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {DiamondUpgradeHelper} from "./helpers/DiamondUpgradeHelper.sol";

contract SVGFacetTest is DiamondUpgradeHelper {
    Diamond internal diamond;

    function setUp() public {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(cutFacet), "DribbleToken", "DT", 18, "OnChain NFT", "OCN");

        ERC721Facet erc721Facet = new ERC721Facet();
        SVGFacet svgFacet = new SVGFacet();

        address[] memory facetAddresses = new address[](2);
        facetAddresses[0] = address(erc721Facet);
        facetAddresses[1] = address(svgFacet);

        string[] memory facetNames = new string[](2);
        facetNames[0] = "ERC721Facet";
        facetNames[1] = "SVGFacet";

        IDiamondCut.FacetCut[] memory cuts = buildAddCutsByNames(facetAddresses, facetNames);
        executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");
    }

    function testSetAndReadCollectionSvg() public {
        ERC721Facet nft = ERC721Facet(address(diamond));
        SVGFacet svg = SVGFacet(address(diamond));

        nft.erc721mint(address(this));

        string memory custom = "<svg xmlns='http://www.w3.org/2000/svg'><text x='10' y='20'>hello</text></svg>";
        svg.setCollectionSvg(custom);

        assertEq(svg.collectionSvg(), custom);
        assertEq(svg.getSVG(1), custom);

        string memory uri = svg.getTokenURI(1);
        assertGt(bytes(uri).length, 0);
    }
}
