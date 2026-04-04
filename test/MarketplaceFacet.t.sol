// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../contracts/facets/DiamondLoupeFacet.sol";
import {ERC20Facet} from "../contracts/facets/ERC20Facet.sol";
import {ERC721Facet} from "../contracts/facets/ERC721facet.sol";
import {MarketplaceFacet} from "../contracts/facets/MarketplaceFacet.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../contracts/interfaces/IDiamondLoupe.sol";
import {DiamondUpgradeHelper} from "./helpers/DiamondUpgradeHelper.sol";

contract MarketplaceFacetTest is DiamondUpgradeHelper {
    Diamond internal diamond;

    address internal seller = address(0xA11CE);
    address internal buyer = address(0xB0B);

    function setUp() public {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(cutFacet), "DribbleToken", "DT", 18, "OnChain NFT", "OCN");

        ERC20Facet erc20Facet = new ERC20Facet();
        ERC721Facet erc721Facet = new ERC721Facet();
        MarketplaceFacet marketFacet = new MarketplaceFacet();
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();

        address[] memory setupFacetAddresses = new address[](2);
        setupFacetAddresses[0] = address(loupeFacet);
        setupFacetAddresses[1] = address(erc721Facet);

        string[] memory setupFacetNames = new string[](2);
        setupFacetNames[0] = "DiamondLoupeFacet";
        setupFacetNames[1] = "ERC721Facet";

        IDiamondCut.FacetCut[] memory setupCuts = buildAddCutsByNames(setupFacetAddresses, setupFacetNames);
        executeDiamondCut(IDiamondCut(address(diamond)), setupCuts, address(0), "");

        ERC721Facet(address(diamond)).erc721mint(seller);

        IDiamondCut.FacetCut[] memory erc20Cuts = buildExtendCutsByName(
            IDiamondLoupe(address(diamond)),
            address(erc20Facet),
            "ERC20Facet"
        );
        executeDiamondCut(IDiamondCut(address(diamond)), erc20Cuts, address(0), "");
        ERC20Facet(address(diamond)).mint(buyer, 1_000);

        IDiamondCut.FacetCut[] memory marketCuts = new IDiamondCut.FacetCut[](1);
        marketCuts[0] = buildAddCutByName(address(marketFacet), "MarketplaceFacet");
        executeDiamondCut(IDiamondCut(address(diamond)), marketCuts, address(0), "");
    }

    function testListAndBuyNft() public {
        ERC721Facet nft = ERC721Facet(address(diamond));
        ERC20Facet token = ERC20Facet(address(diamond));
        MarketplaceFacet market = MarketplaceFacet(address(diamond));

        vm.prank(seller);
        market.listNFT(1, 200);
        assertTrue(market.isListed(1));

        vm.prank(buyer);
        market.buyNFT(1);

        assertEq(nft.ownerOf(1), buyer);
        assertEq(token.balanceOf(seller), 200);
        assertEq(token.balanceOf(buyer), 800);
        assertFalse(market.isListed(1));
    }
}
