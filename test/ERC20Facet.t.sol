// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {ERC20Facet} from "../contracts/facets/ERC20Facet.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {DiamondUpgradeHelper} from "./helpers/DiamondUpgradeHelper.sol";

contract ERC20FacetTest is DiamondUpgradeHelper {
	Diamond internal diamond;
	ERC20Facet internal erc20Facet;

	address internal alice = address(0xA11CE);
	address internal bob = address(0xB0B);

	function setUp() public {
		DiamondCutFacet cutFacet = new DiamondCutFacet();
		diamond = new Diamond(address(this), address(cutFacet), "DribbleToken", "DT", 18, "OnChain NFT", "OCN");

		erc20Facet = new ERC20Facet();
		IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
		cuts[0] = buildAddCutByName(address(erc20Facet), "ERC20Facet");
		executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");
	}

	function testMintAndTransfer() public {
		ERC20Facet token = ERC20Facet(address(diamond));

		token.mint(alice, 1_000);
		vm.prank(alice);
		bool ok = token.transfer(bob, 250);

		assertTrue(ok);
		assertEq(token.balanceOf(alice), 750);
		assertEq(token.balanceOf(bob), 250);
		assertEq(token.totalSupply(), 1_000);
	}

	function testApproveAndTransferFrom() public {
		ERC20Facet token = ERC20Facet(address(diamond));

		token.mint(alice, 500);
		vm.prank(alice);
		token.approve(address(this), 300);

		bool ok = token.transferFrom(alice, bob, 200);
		assertTrue(ok);
		assertEq(token.allowance(alice, address(this)), 100);
		assertEq(token.balanceOf(alice), 300);
		assertEq(token.balanceOf(bob), 200);
	}

}
