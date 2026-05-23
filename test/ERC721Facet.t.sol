// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {ERC721Facet} from "../contracts/facets/ERC721facet.sol";
import {VRFFacet} from "../contracts/facets/VRFfacet.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {ReqData} from "../contracts/libraries/AppStorage.sol";
import {DiamondUpgradeHelper} from "./helpers/DiamondUpgradeHelper.sol";

contract MockVRFCoordinator {
	uint256 internal nextRequestId = 1;

	struct RandomWordsRequest {
		bytes32 keyHash;
		uint256 subId;
		uint16 requestConfirmations;
		uint32 callbackGasLimit;
		uint32 numWords;
		bytes extraArgs;
	}

	function requestRandomWords(RandomWordsRequest memory) external returns (uint256 requestId) {
		requestId = nextRequestId;
		nextRequestId += 1;
	}
}

contract ERC721FacetTest is DiamondUpgradeHelper {
	Diamond internal diamond;
	ERC721Facet internal erc721Facet;
	VRFFacet internal vrfFacet;
	MockVRFCoordinator internal mockVrf;

	address internal alice = address(0xA11CE);
	address internal bob = address(0xB0B);

	function setUp() public {
		DiamondCutFacet cutFacet = new DiamondCutFacet();
		diamond = new Diamond(address(this), address(cutFacet), "DribbleToken", "DT", 18, "OnChain NFT", "OCN");

		erc721Facet = new ERC721Facet();
		vrfFacet = new VRFFacet();
		address[] memory facetAddresses = new address[](2);
		facetAddresses[0] = address(erc721Facet);
		facetAddresses[1] = address(vrfFacet);
		string[] memory facetNames = new string[](2);
		facetNames[0] = "ERC721Facet";
		facetNames[1] = "VRFFacet";
		IDiamondCut.FacetCut[] memory cuts = buildAddCutsByNames(facetAddresses, facetNames);
		executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");

		mockVrf = new MockVRFCoordinator();
		ERC721Facet(address(diamond)).setReqData(
			ReqData({
				subscriptionId: 1,
				keyHash: bytes32(uint256(1)),
				callbackGasLimit: 200000,
				requestConfirmations: 3,
				numWords: 2,
				vrfCoordinator: address(mockVrf)
			})
		);
	}

	function testMintAndTransferFrom() public {
		ERC721Facet token = ERC721Facet(address(diamond));

		bool minted = token.erc721mint(alice);
		assertTrue(minted);
		assertEq(token.ownerOf(1), alice);
		assertEq(token.erc721balanceOf(alice), 1);

		vm.prank(alice);
		token.erc721transferFrom(alice, bob, 1);

		assertEq(token.ownerOf(1), bob);
		assertEq(token.erc721balanceOf(alice), 0);
		assertEq(token.erc721balanceOf(bob), 1);
	}

	function testTokenUriAfterMint() public {
		ERC721Facet token = ERC721Facet(address(diamond));
		token.erc721mint(alice);

		string memory uri = token.tokenURI(1);
		assertGt(bytes(uri).length, 0);
		assertTrue(_contains(uri, '"name":"OnChain NFT #1"'));
		assertTrue(_contains(uri, '"symbol":"OCN"'));
		assertTrue(_contains(uri, '"owner":"0x00000000000000000000000000000000000a11ce"'));
		assertTrue(_contains(uri, '"balance":"1"'));
		assertTrue(_contains(uri, '"image":"data:image/svg+xml;utf8,'));
	}

	function _contains(string memory text, string memory needle) internal pure returns (bool) {
		bytes memory textBytes = bytes(text);
		bytes memory needleBytes = bytes(needle);
		if (needleBytes.length == 0 || needleBytes.length > textBytes.length) return false;

		for (uint256 i = 0; i <= textBytes.length - needleBytes.length; i++) {
			bool matchFound = true;
			for (uint256 j = 0; j < needleBytes.length; j++) {
				if (textBytes[i + j] != needleBytes[j]) {
					matchFound = false;
					break;
				}
			}
			if (matchFound) return true;
		}
		return false;
	}

}
