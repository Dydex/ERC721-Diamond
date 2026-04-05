// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../contracts/interfaces/IDiamondLoupe.sol";
import {DiamondUpgradeHelper} from "../test/helpers/DiamondUpgradeHelper.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/VRFfacet.sol";
import "../contracts/libraries/AppStorage.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/ERC721facet.sol";
import "../contracts/facets/MarketplaceFacet.sol";
import "../contracts/facets/StakingFacet.sol";
import "../contracts/facets/ERC721BorrowerFacet.sol";
import "../contracts/facets/SVGfacet.sol";
import "../contracts/facets/MultiSigFacet.sol";

contract DiamondUpgradeExample is Script, DiamondUpgradeHelper {
    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        Diamond diamond = new Diamond(
            deployer,
            address(dCutFacet),
            "Dribble",
            "DRIB",
            18,
            "DribbleNFT",
            "DRIBNFT"
        );

        address[] memory addAddresses = new address[](10);
        addAddresses[0] = address(new DiamondLoupeFacet());
        addAddresses[1] = address(new OwnershipFacet());
        addAddresses[2] = address(new ERC721Facet());
        addAddresses[3] = address(new ERC20Facet());
        addAddresses[4] = address(new StakingFacet());
        addAddresses[5] = address(new MarketplaceFacet());
        addAddresses[6] = address(new ERC721BorrowerFacet());
        addAddresses[7] = address(new SVGFacet());
        addAddresses[8] = address(new MultiSigFacet());
        addAddresses[9] = address(new VRFFacet());

        string[] memory names = new string[](10);
        names[0] = "DiamondLoupeFacet";
        names[1] = "OwnershipFacet";
        names[2] = "ERC721Facet";
        names[3] = "ERC20Facet";
        names[4] = "StakingFacet";
        names[5] = "MarketplaceFacet";
        names[6] = "ERC721BorrowerFacet";
        names[7] = "SVGFacet";
        names[8] = "MultiSigFacet";
        names[9] = "VRFFacet";

        IDiamondCut.FacetCut[] memory cuts = buildAddCutsByNames(
            addAddresses,
            names
        );


        executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");
        ERC721Facet(address(diamond)).setReqData(_defaultReqData());


        // ERC721Facet(0x1eb115d63bcff02032c4c3277a4e171b2aed44e2).erc721mint(deployer);
        // ERC721Facet(0x1eb115d63bcff02032c4c3277a4e171b2aed44e2).erc721mint(deployer);
        // ERC721Facet(0x1eb115d63bcff02032c4c3277a4e171b2aed44e2).erc721mint(deployer);
        // ERC721Facet(0x1eb115d63bcff02032c4c3277a4e171b2aed44e2).erc721mint(deployer);

        vm.stopBroadcast();
    }

    function _defaultReqData() internal pure returns (ReqData memory req) {
        req = ReqData({
            subscriptionId: 86392481266004926467087815624602525576181908648184018140908093926353287551762,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 2500000,
            requestConfirmations: 3,
            numWords: 2,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
        });
    }
}