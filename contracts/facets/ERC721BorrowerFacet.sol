// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorage, BorrowPosition} from "../libraries/AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract ERC721BorrowerFacet {
    AppStorage internal s;

    
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event CollateralFeeSet(uint256 fee);
    event RepaymentPeriodSet(uint256 period);
    event ListedForBorrow(uint256 indexed tokenId, address indexed owner);
    event DelistedFromBorrow(uint256 indexed tokenId, address indexed owner);
    event NFTBorrowed(uint256 indexed tokenId, address indexed borrower, uint256 collateral, uint256 deadline);
    event NFTReturned(uint256 indexed tokenId, address indexed borrower);
    event BorrowLiquidated(uint256 indexed tokenId, address indexed originalOwner, uint256 collateral);

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    } 

    // Set the ERC20 collateral fee required to borrow an NFT
    function setCollateralFee(uint256 _fee) external onlyOwner {
        require(_fee > 0, "Borrower: fee must be > 0");
        s.borrowCollateralFee = _fee;
        emit CollateralFeeSet(_fee);
    }

    // Set the repayment window (seconds) for borrowed NFTs
    function setRepaymentPeriod(uint256 _period) external onlyOwner {
        require(_period > 0, "Borrower: period must be > 0");
        s.borrowRepaymentPeriod = _period;
        emit RepaymentPeriodSet(_period);
    }

   
    function listForBorrow(uint256 _tokenId) external {
        require(s.owners[_tokenId] == msg.sender, "Borrower: not token owner");
        require(s.borrows[_tokenId].originalOwner == address(0), "Borrower: already listed");
        require(s.borrowCollateralFee > 0, "Borrower: collateral fee not set");
        require(s.borrowRepaymentPeriod > 0, "Borrower: repayment period not set");

        _transferNFT(msg.sender, address(this), _tokenId);

        s.borrows[_tokenId] = BorrowPosition({
            originalOwner: msg.sender,
            borrower: address(0),
            collateralAmount: 0,
            returnDeadline: 0
        });

        emit ListedForBorrow(_tokenId, msg.sender);
    }

    
    function delistBorrow(uint256 _tokenId) external {
        BorrowPosition storage pos = s.borrows[_tokenId];
        require(pos.originalOwner == msg.sender, "Borrower: not original owner");
        require(pos.borrower == address(0), "Borrower: already borrowed");

        delete s.borrows[_tokenId];

        // Return NFT to owner
        _transferNFT(address(this), msg.sender, _tokenId);

        emit DelistedFromBorrow(_tokenId, msg.sender);
    }

    
    function borrowNFT(uint256 _tokenId) external {
        BorrowPosition storage pos = s.borrows[_tokenId];
        require(pos.originalOwner != address(0), "Borrower: not listed");
        require(pos.borrower == address(0), "Borrower: already borrowed");
        require(msg.sender != pos.originalOwner, "Borrower: cannot borrow own NFT");

        uint256 fee = s.borrowCollateralFee;
        require(s.erc20Balances[msg.sender] >= fee, "Borrower: insufficient ERC20 collateral");

        s.erc20Balances[msg.sender] -= fee;
        s.erc20Balances[address(this)] += fee;

        _transferNFT(address(this), msg.sender, _tokenId);

        pos.borrower = msg.sender;
        pos.collateralAmount = fee;
        pos.returnDeadline = block.timestamp + s.borrowRepaymentPeriod;

        emit NFTBorrowed(_tokenId, msg.sender, fee, pos.returnDeadline);
    }

    function returnNFT(uint256 _tokenId) external {
        BorrowPosition storage pos = s.borrows[_tokenId];
        require(pos.borrower == msg.sender, "Borrower: not borrower");
        require(s.owners[_tokenId] == msg.sender, "Borrower: must own NFT to return");
        require(block.timestamp <= pos.returnDeadline, "Borrower: past deadline");

        address originalOwner = pos.originalOwner;
        uint256 collateral = pos.collateralAmount;

        delete s.borrows[_tokenId];

        _transferNFT(msg.sender, originalOwner, _tokenId);

        s.erc20Balances[address(this)] -= collateral;
        s.erc20Balances[msg.sender] += collateral;

        emit NFTReturned(_tokenId, msg.sender);
    }

    function liquidate(uint256 _tokenId) external {
        BorrowPosition storage pos = s.borrows[_tokenId];
        require(pos.borrower != address(0), "Borrower: not borrowed");
        require(block.timestamp > pos.returnDeadline, "Borrower: not past deadline");

        address originalOwner = pos.originalOwner;
        uint256 collateral = pos.collateralAmount;

        delete s.borrows[_tokenId];

        s.erc20Balances[address(this)] -= collateral;
        s.erc20Balances[originalOwner] += collateral;

        emit BorrowLiquidated(_tokenId, originalOwner, collateral);
    }


    function getBorrowInfo(uint256 _tokenId)
        external
        view
        returns (
            address originalOwner,
            address borrower,
            uint256 collateralAmount,
            uint256 returnDeadline
        )
    {
        BorrowPosition memory pos = s.borrows[_tokenId];
        return (pos.originalOwner, pos.borrower, pos.collateralAmount, pos.returnDeadline);
    }

    function getCollateralFee() external view returns (uint256) {
        return s.borrowCollateralFee;
    }

    function getRepaymentPeriod() external view returns (uint256) {
        return s.borrowRepaymentPeriod;
    }

    function _transferNFT(address _from, address _to, uint256 _tokenId) private {
        delete s.tokenApprovals[_tokenId];
        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }
}
