// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {MultiSigFacet} from "../contracts/facets/MultiSigFacet.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {DiamondUpgradeHelper} from "./helpers/DiamondUpgradeHelper.sol";

contract MultiSigTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract MultiSigFacetTest is DiamondUpgradeHelper {
    Diamond internal diamond;
    MultiSigTarget internal target;

    address internal signer1 = address(0xA11CE);
    address internal signer2 = address(0xB0B);

    function setUp() public {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(cutFacet), "DribbleToken", "DT", 18, "OnChain NFT", "OCN");

        MultiSigFacet msFacet = new MultiSigFacet();
        target = new MultiSigTarget();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = buildAddCutByName(address(msFacet), "MultiSigFacet");
        executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");
    }

    function testInitializeSubmitConfirmAndExecute() public {
        MultiSigFacet ms = MultiSigFacet(address(diamond));

        address[] memory signers = new address[](2);
        signers[0] = signer1;
        signers[1] = signer2;
        ms.initializeMultiSig(signers, 2);
        assertEq(ms.getQuorum(), 2);

        bytes memory data = abi.encodeWithSelector(MultiSigTarget.setValue.selector, 7);

        vm.prank(signer1);
        uint256 txId = ms.submitTransaction(address(target), 0, data);

        vm.prank(signer1);
        ms.confirmTransaction(txId);
        vm.prank(signer2);
        ms.confirmTransaction(txId);

        vm.prank(signer1);
        ms.executeTransaction(txId);

        assertEq(target.value(), 7);
    }
}
