// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../contracts/facets/DiamondLoupeFacet.sol";
import {ERC20Facet} from "../contracts/facets/ERC20Facet.sol";
import {ERC721Facet} from "../contracts/facets/ERC721facet.sol";
import {ERC721BorrowerFacet} from "../contracts/facets/ERC721BorrowerFacet.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../contracts/interfaces/IDiamondLoupe.sol";
import {DiamondUpgradeHelper} from "./helpers/DiamondUpgradeHelper.sol";

contract ERC721BorrowerFacetTest is DiamondUpgradeHelper {
    Diamond internal diamond;

    address internal ownerNft = address(0xA11CE);
    address internal borrower = address(0xB0B);

    function setUp() public {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(cutFacet), "DribbleToken", "DT", 18, "OnChain NFT", "OCN");

        ERC20Facet erc20Facet = new ERC20Facet();
        ERC721Facet erc721Facet = new ERC721Facet();
        ERC721BorrowerFacet borrowerFacet = new ERC721BorrowerFacet();
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();

        address[] memory setupFacetAddresses = new address[](2);
        setupFacetAddresses[0] = address(loupeFacet);
        setupFacetAddresses[1] = address(erc721Facet);

        string[] memory setupFacetNames = new string[](2);
        setupFacetNames[0] = "DiamondLoupeFacet";
        setupFacetNames[1] = "ERC721Facet";

        IDiamondCut.FacetCut[] memory setupCuts = buildAddCutsByNames(setupFacetAddresses, setupFacetNames);
        executeDiamondCut(IDiamondCut(address(diamond)), setupCuts, address(0), "");

        ERC721Facet(address(diamond)).erc721mint(ownerNft);

        IDiamondCut.FacetCut[] memory erc20Cuts = buildExtendCutsByName(
            IDiamondLoupe(address(diamond)),
            address(erc20Facet),
            "ERC20Facet"
        );
        executeDiamondCut(IDiamondCut(address(diamond)), erc20Cuts, address(0), "");
        ERC20Facet(address(diamond)).mint(borrower, 500);

        IDiamondCut.FacetCut[] memory borrowerCuts = new IDiamondCut.FacetCut[](1);
        borrowerCuts[0] = buildAddCutByName(address(borrowerFacet), "ERC721BorrowerFacet");
        executeDiamondCut(IDiamondCut(address(diamond)), borrowerCuts, address(0), "");
    }

    function testBorrowAndReturnNft() public {
        ERC721Facet nft = ERC721Facet(address(diamond));
        ERC20Facet token = ERC20Facet(address(diamond));
        ERC721BorrowerFacet borrow = ERC721BorrowerFacet(address(diamond));

        borrow.setCollateralFee(100);
        borrow.setRepaymentPeriod(1 days);

        vm.prank(ownerNft);
        borrow.listForBorrow(1);

        vm.prank(borrower);
        borrow.borrowNFT(1);

        assertEq(nft.ownerOf(1), borrower);
        assertEq(token.balanceOf(borrower), 400);

        vm.prank(borrower);
        borrow.returnNFT(1);

        assertEq(nft.ownerOf(1), ownerNft);
        assertEq(token.balanceOf(borrower), 500);
    }
}
