// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/ERC721facet.sol";
import "../contracts/facets/ERC721BorrowerFacet.sol";
import "../contracts/facets/MarketplaceFacet.sol";
import "../contracts/facets/MultiSigFacet.sol";
import "../contracts/facets/StakingFacet.sol";
import "../contracts/facets/SVGfacet.sol";
import "../contracts/Diamond.sol";

import "./helpers/DiamondUpgradeHelper.sol";

contract DiamondDeployer is DiamondUpgradeHelper {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    ERC20Facet erc20Facet;
    ERC721Facet erc721Facet;
    ERC721BorrowerFacet erc721BorrowerFacet;
    MarketplaceFacet marketplaceFacet;
    MultiSigFacet multiSigFacet;
    StakingFacet stakingFacet;
    SVGFacet svgFacet;

    function testDeployDiamond() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(
            address(this),
            address(dCutFacet),
            "DribbleToken",
            "DT",
            18,
            "OnChain NFT",
            "OCN"
        );
        dLoupe = new DiamondLoupeFacet();
        erc20Facet = new ERC20Facet();
        erc721Facet = new ERC721Facet();
        erc721BorrowerFacet = new ERC721BorrowerFacet();
        marketplaceFacet = new MarketplaceFacet();
        multiSigFacet = new MultiSigFacet();
        stakingFacet = new StakingFacet();
        svgFacet = new SVGFacet();

        // Add loupe first so helper can resolve/replace overlapping selectors.
        IDiamondCut.FacetCut[] memory loupeCut = new IDiamondCut.FacetCut[](1);
        loupeCut[0] = buildAddCutByName(address(dLoupe), "DiamondLoupeFacet");
        executeDiamondCut(IDiamondCut(address(diamond)), loupeCut, address(0), "");

        // Deploy the seven app facets with collision-safe extend cuts.
        address[] memory appFacetAddresses = new address[](7);
        appFacetAddresses[0] = address(erc20Facet);
        appFacetAddresses[1] = address(erc721Facet);
        appFacetAddresses[2] = address(erc721BorrowerFacet);
        appFacetAddresses[3] = address(marketplaceFacet);
        appFacetAddresses[4] = address(multiSigFacet);
        appFacetAddresses[5] = address(stakingFacet);
        appFacetAddresses[6] = address(svgFacet);

        string[] memory appFacetNames = new string[](7);
        appFacetNames[0] = "ERC20Facet";
        appFacetNames[1] = "ERC721Facet";
        appFacetNames[2] = "ERC721BorrowerFacet";
        appFacetNames[3] = "MarketplaceFacet";
        appFacetNames[4] = "MultiSigFacet";
        appFacetNames[5] = "StakingFacet";
        appFacetNames[6] = "SVGFacet";

        for (uint256 i = 0; i < appFacetAddresses.length; i++) {
            IDiamondCut.FacetCut[] memory cuts = buildExtendCutsByName(
                IDiamondLoupe(address(diamond)),
                appFacetAddresses[i],
                appFacetNames[i]
            );
            if (cuts.length > 0) {
                executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");
            }
        }

        // Keep this test focused on deployment/cut execution only.
        assertTrue(address(diamond) != address(0));
    }
}
