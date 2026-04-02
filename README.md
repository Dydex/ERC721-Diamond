# ERC721 Diamond (Beginner Guide)

This repository is an implementation of EIP-2535 (Diamond Standard) with an ERC721 facet.

If Diamonds still feel confusing, the shortest mental model is:

1. The Diamond is one contract address users interact with.
2. That address does not contain all logic directly.
3. It forwards each function call to a facet contract based on function selector.
4. All facets share the same storage because they run via delegatecall.
5. You can upgrade by changing selector -> facet mappings via diamondCut.

## Why use a Diamond?

1. You avoid contract size limits by splitting logic into facets.
2. You can upgrade specific groups of functions without redeploying everything.
3. You keep one stable address for users and integrations.

Tradeoff: architecture is more complex than a single contract and storage layout discipline is critical.

## Core concept in this repo

There are two main storage areas:

1. Diamond routing storage in LibDiamond:
   - selector to facet mapping
   - facet selector lists
   - ownership
   - ERC165 support flags
2. App storage in LibAppStorage:
   - ERC721 data (name, symbol, owners, balances, approvals, totalSupply)

Because facets execute through delegatecall, they read/write the Diamond storage, not their own.

## How a call flows

1. User calls Diamond address.
2. Diamond fallback reads msg.sig.
3. Fallback finds facet from selectorToFacetAndPosition.
4. Fallback delegatecalls facet.
5. Facet logic executes with Diamond storage context.

## File-by-file guide

### Root config

- foundry.toml
  - Foundry settings for build/test/script behavior.
  - Important here: ffi is enabled for selector generation helpers in tests.

- remappings.txt
  - Import path remappings (forge-std and solidity-stringutils).

### contracts/

- [contracts/Diamond.sol](contracts/Diamond.sol)
  - The proxy-like entrypoint users call.
  - Constructor sets owner and installs only diamondCut at deployment.
  - fallback() routes function selectors to facets via delegatecall.
  - example() is an immutable function in the Diamond itself.

#### contracts/libraries/

- [contracts/libraries/LibDiamond.sol](contracts/libraries/LibDiamond.sol)
  - Brain of selector routing and upgrades.
  - Defines DiamondStorage at fixed slot keccak256("diamond.standard.diamond.storage").
  - Implements add/replace/remove selector logic.
  - Enforces owner checks and code-existence checks.
  - Emits DiamondCut and OwnershipTransferred events.

- [contracts/libraries/LibAppStorage.sol](contracts/libraries/LibAppStorage.sol)
  - App-specific shared storage for ERC721 facet(s).
  - Uses slot 0 for AppStorage.
  - Current fields include name, symbol, owners, balances, approvals, totalSupply.

#### contracts/interfaces/

- [contracts/interfaces/IDiamondCut.sol](contracts/interfaces/IDiamondCut.sol)
  - Standard upgrade interface with FacetCut and diamondCut.

- [contracts/interfaces/IDiamondLoupe.sol](contracts/interfaces/IDiamondLoupe.sol)
  - Standard view interface to inspect facet addresses/selectors.

- [contracts/interfaces/IERC165.sol](contracts/interfaces/IERC165.sol)
  - ERC165 supportsInterface interface.

- [contracts/interfaces/IERC173.sol](contracts/interfaces/IERC173.sol)
  - Ownership standard interface for owner and transferOwnership.

- [contracts/interfaces/IERC721.sol](contracts/interfaces/IERC721.sol)
  - ERC721 external function/event interface used by ERC721Facet.

- [contracts/interfaces/IERC721Receiver.sol](contracts/interfaces/IERC721Receiver.sol)
  - Receiver callback interface for safe NFT transfers to contracts.

#### contracts/facets/

- [contracts/facets/DiamondCutFacet.sol](contracts/facets/DiamondCutFacet.sol)
  - Exposes external diamondCut.
  - Restricts upgrade calls to owner.
  - Delegates implementation details to LibDiamond.

- [contracts/facets/DiamondLoupeFacet.sol](contracts/facets/DiamondLoupeFacet.sol)
  - Read-only introspection tools.
  - Lets you query facets, selectors, and supportsInterface.

- [contracts/facets/OwnershipFacet.sol](contracts/facets/OwnershipFacet.sol)
  - Exposes owner() and transferOwnership().

- [contracts/facets/ERC721facet.sol](contracts/facets/ERC721facet.sol)
  - Your NFT business logic.
  - Initializes name/symbol and marks IERC721 as supported.
  - Implements minting, approvals, transfers, safe transfers.
  - tokenURI is fully on-chain JSON + SVG generation.
  - Uses AppStorage via LibAppStorage.diamondStorage().

#### contracts/upgradeInitializers/

- [contracts/upgradeInitializers/DiamondInit.sol](contracts/upgradeInitializers/DiamondInit.sol)
  - Optional initializer to set supported interface ids during cut.
  - Pattern: pass this as _init with init() calldata during upgrade/deploy cut.

### script/

- [script/DiamondUpgradeExample.s.sol](script/DiamondUpgradeExample.s.sol)
  - Foundry broadcast script template for add/replace/remove upgrades.
  - Uses DiamondUpgradeHelper to generate cuts from facet names.

### test/

- [test/deployDiamond.t.sol](test/deployDiamond.t.sol)
  - Example deploy and first upgrade flow in tests.
  - Deploys DiamondCutFacet + Diamond, then adds Loupe and Ownership facets.

- [test/helpers/DiamondUtils.sol](test/helpers/DiamondUtils.sol)
  - Uses forge inspect via FFI to derive selectors from facet ABI signatures.

- [test/helpers/DiamondUpgradeHelper.sol](test/helpers/DiamondUpgradeHelper.sol)
  - Utility layer to build add/replace/remove/extend cuts safely.
  - Reduces boilerplate when upgrading in tests/scripts.

### lib/

- lib/forge-std
  - Foundry standard library for Test, Script, Vm utilities.

- lib/solidity-stringutils
  - String helpers used by selector parsing helper.

## Deployment and upgrade lifecycle (practical)

1. Deploy DiamondCutFacet.
2. Deploy Diamond with owner and DiamondCutFacet address.
3. Deploy other facets (Loupe, Ownership, ERC721, etc.).
4. Build FacetCut[] for Add/Replace/Remove.
5. Call diamondCut through Diamond address.
6. Optionally execute initializer (_init + _calldata).

## Diamond storage safety rules

1. Never change existing AppStorage field order/types after deployment.
2. Only append new fields at the end of AppStorage for upgrades.
3. Keep all facets using the same AppStorage definition.
4. Be careful when removing fields if a Diamond is already live.

## Common confusion points (and quick answers)

1. Is Diamond like a proxy?
   - Yes, conceptually. It routes calls, but routing table is selector-based and multi-facet.

2. Where is state actually stored?
   - In the Diamond storage context. Facets do not keep independent state.

3. Why both LibDiamond and LibAppStorage?
   - LibDiamond is framework-level routing/ownership storage.
   - LibAppStorage is app-level domain data (your ERC721 state).

4. What does diamondCut actually change?
   - It updates mapping from function selectors to facet addresses.

## Useful commands

```bash
forge build
forge test -vv
forge script script/DiamondUpgradeExample.s.sol:DiamondUpgradeExample --rpc-url <RPC_URL> --private-key <PK> --broadcast
```

## If you want this even simpler

Start by reading in this exact order:

1. [contracts/Diamond.sol](contracts/Diamond.sol)
2. [contracts/libraries/LibDiamond.sol](contracts/libraries/LibDiamond.sol)
3. [contracts/libraries/LibAppStorage.sol](contracts/libraries/LibAppStorage.sol)
4. [contracts/facets/DiamondCutFacet.sol](contracts/facets/DiamondCutFacet.sol)
5. [contracts/facets/ERC721facet.sol](contracts/facets/ERC721facet.sol)

After these five files, the architecture usually clicks.
