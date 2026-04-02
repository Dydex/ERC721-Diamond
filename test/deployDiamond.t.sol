// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721facet.sol";
import "../contracts/Diamond.sol";

import "./helpers/DiamondUpgradeHelper.sol";

contract DiamondDeployer is DiamondUpgradeHelper {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721Facet erc721Facet;

    function testDeployDiamond() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc721Facet = new ERC721Facet();
        address user1 = address(1);

        // Upgrade diamond with facets using helper (one-shot add cuts)
        address[] memory addAddrs = new address[](3);
        addAddrs[0] = address(dLoupe);
        addAddrs[1] = address(ownerF);
        addAddrs[2] = address(erc721Facet);

        string[] memory names = new string[](3);
        names[0] = "DiamondLoupeFacet";
        names[1] = "OwnershipFacet";
        names[2] = "ERC721Facet";

        IDiamondCut.FacetCut[] memory cuts = buildAddCutsByNames(
            addAddrs,
            names
        );
        executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");

        // initialize NFT metadata
        ERC721Facet(address(diamond)).initERC721("OnChain NFT", "OCN");

        // mint token id 1 to this test contract
        bool minted = ERC721Facet(address(diamond)).mint(user1, 1);
        assertTrue(minted);


        // verify ERC721 state through the diamond
        assertEq(ERC721Facet(address(diamond)).name(), "OnChain NFT");
        assertEq(ERC721Facet(address(diamond)).symbol(), "OCN");
        assertEq(ERC721Facet(address(diamond)).ownerOf(1), user1);
        assertEq(ERC721Facet(address(diamond)).balanceOf(user1), 1);

        string memory uri = ERC721Facet(address(diamond)).tokenURI(1);
        assertGt(bytes(uri).length, 0);
        
    }
}
