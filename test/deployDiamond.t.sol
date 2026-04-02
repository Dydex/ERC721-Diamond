// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";

import "./helpers/DiamondUpgradeHelper.sol";

contract DiamondDeployer is DiamondUpgradeHelper {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;

    function testDeployDiamond() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();

        // Upgrade diamond with facets using helper (one-shot add cuts)
        address[] memory addAddrs = new address[](2);
        addAddrs[0] = address(dLoupe);
        addAddrs[1] = address(ownerF);

        string[] memory names = new string[](2);
        names[0] = "DiamondLoupeFacet";
        names[1] = "OwnershipFacet";

        IDiamondCut.FacetCut[] memory cuts = buildAddCutsByNames(
            addAddrs,
            names
        );
        executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }
}
