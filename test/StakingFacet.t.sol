// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../contracts/facets/DiamondLoupeFacet.sol";
import {ERC20Facet} from "../contracts/facets/ERC20Facet.sol";
import {ERC721Facet} from "../contracts/facets/ERC721facet.sol";
import {StakingFacet} from "../contracts/facets/StakingFacet.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../contracts/interfaces/IDiamondLoupe.sol";
import {DiamondUpgradeHelper} from "./helpers/DiamondUpgradeHelper.sol";

contract StakingFacetTest is DiamondUpgradeHelper {
    Diamond internal diamond;
    address internal alice = address(0xA11CE);

    function setUp() public {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(cutFacet), "DribbleToken", "DT", 18, "OnChain NFT", "OCN");

        ERC20Facet erc20Facet = new ERC20Facet();
        ERC721Facet erc721Facet = new ERC721Facet();
        StakingFacet stakingFacet = new StakingFacet();
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();

        address[] memory setupFacetAddresses = new address[](2);
        setupFacetAddresses[0] = address(loupeFacet);
        setupFacetAddresses[1] = address(erc721Facet);

        string[] memory setupFacetNames = new string[](2);
        setupFacetNames[0] = "DiamondLoupeFacet";
        setupFacetNames[1] = "ERC721Facet";

        IDiamondCut.FacetCut[] memory setupCuts = buildAddCutsByNames(setupFacetAddresses, setupFacetNames);
        executeDiamondCut(IDiamondCut(address(diamond)), setupCuts, address(0), "");

        ERC721Facet(address(diamond)).mint(alice, 1);

        IDiamondCut.FacetCut[] memory erc20Cuts = buildExtendCutsByName(
            IDiamondLoupe(address(diamond)),
            address(erc20Facet),
            "ERC20Facet"
        );
        executeDiamondCut(IDiamondCut(address(diamond)), erc20Cuts, address(0), "");
        ERC20Facet(address(diamond)).mint(address(diamond), 1_000);

        IDiamondCut.FacetCut[] memory stakingCuts = new IDiamondCut.FacetCut[](1);
        stakingCuts[0] = buildAddCutByName(address(stakingFacet), "StakingFacet");
        executeDiamondCut(IDiamondCut(address(diamond)), stakingCuts, address(0), "");
    }

    function testStakeClaimRewardAndUnstake() public {
        ERC20Facet token = ERC20Facet(address(diamond));
        ERC721Facet nft = ERC721Facet(address(diamond));
        StakingFacet staking = StakingFacet(address(diamond));

        staking.setStakingConfig(1 days, 100);

        vm.prank(alice);
        staking.stakeNFT(1);

        vm.warp(block.timestamp + 1 days);

        vm.prank(alice);
        staking.claimReward(1);
        assertEq(token.balanceOf(alice), 100);

        vm.prank(alice);
        staking.unstakeNFT(1);
        assertEq(nft.ownerOf(1), alice);
    }
}
