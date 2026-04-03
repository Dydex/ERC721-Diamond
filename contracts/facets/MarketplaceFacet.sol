// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorage, Listing} from "../libraries/AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract MarketplaceFacet {
    AppStorage internal s;

    // ERC721 Transfer event for NFT movements
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTDelisted(uint256 indexed tokenId, address indexed seller);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    // ── List / Delist ───────────────────────────────────────────────────────

    // List an NFT for sale (price in ERC20 tokens). NFT is escrowed.
    function listNFT(uint256 _tokenId, uint256 _price) external {
        require(s.owners[_tokenId] == msg.sender, "Marketplace: not token owner");
        require(_price > 0, "Marketplace: price must be > 0");
        require(!s.listings[_tokenId].active, "Marketplace: already listed");

        // Escrow NFT in diamond
        _transferNFT(msg.sender, address(this), _tokenId);

        s.listings[_tokenId] = Listing({
            seller: msg.sender,
            price: _price,
            active: true
        });

        emit NFTListed(_tokenId, msg.sender, _price);
    }

    // Remove a listing and return the NFT to the seller
    function delistNFT(uint256 _tokenId) external {
        Listing storage listing = s.listings[_tokenId];
        require(listing.active, "Marketplace: not listed");
        require(listing.seller == msg.sender, "Marketplace: not seller");

        delete s.listings[_tokenId];

        // Return NFT to seller
        _transferNFT(address(this), msg.sender, _tokenId);

        emit NFTDelisted(_tokenId, msg.sender);
    }

    // ── Buy ─────────────────────────────────────────────────────────────────

    // Buy a listed NFT — ERC20 is transferred from buyer to seller
    function buyNFT(uint256 _tokenId) external {
        Listing storage listing = s.listings[_tokenId];
        require(listing.active, "Marketplace: not listed");
        require(msg.sender != listing.seller, "Marketplace: cannot buy own NFT");

        uint256 price = listing.price;
        address seller = listing.seller;

        require(s.erc20Balances[msg.sender] >= price, "Marketplace: insufficient ERC20 balance");

        // Clear listing first (reentrancy protection)
        delete s.listings[_tokenId];

        // Transfer ERC20: buyer → seller
        s.erc20Balances[msg.sender] -= price;
        s.erc20Balances[seller] += price;

        // Transfer NFT: diamond → buyer
        _transferNFT(address(this), msg.sender, _tokenId);

        emit NFTSold(_tokenId, seller, msg.sender, price);
    }

    // ── View Functions ──────────────────────────────────────────────────────

    function getListing(uint256 _tokenId)
        external
        view
        returns (address seller, uint256 price, bool active)
    {
        Listing memory listing = s.listings[_tokenId];
        return (listing.seller, listing.price, listing.active);
    }

    function isListed(uint256 _tokenId) external view returns (bool) {
        return s.listings[_tokenId].active;
    }

    // ── Internal ────────────────────────────────────────────────────────────

    function _transferNFT(address _from, address _to, uint256 _tokenId) private {
        delete s.tokenApprovals[_tokenId];
        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }
}
