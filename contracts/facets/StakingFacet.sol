// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorage, StakePosition} from "../libraries/AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract StakingFacet {
    AppStorage internal s;

    
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event NFTStaked(address indexed staker, uint256 indexed tokenId, uint256 unlockTime);
    event NFTUnstaked(address indexed staker, uint256 indexed tokenId);
    event RewardClaimed(address indexed staker, uint256 indexed tokenId, uint256 rewardAmount);
    event StakingConfigUpdated(uint256 lockPeriod, uint256 rewardAmount);

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    function setStakingConfig(uint256 _lockPeriod, uint256 _rewardAmount) external onlyOwner {
        s.stakeLockPeriod = _lockPeriod;
        s.stakeRewardAmount = _rewardAmount;
        emit StakingConfigUpdated(_lockPeriod, _rewardAmount);
    }

    function stakeNFT(uint256 _tokenId) external {
        require(s.owners[_tokenId] == msg.sender, "Staking: not token owner");
        require(s.stakes[_tokenId].staker == address(0), "Staking: already staked");
        require(s.stakeLockPeriod > 0, "Staking: lock period not set");

        _transferNFT(msg.sender, address(this), _tokenId);

        uint256 unlockTime = block.timestamp + s.stakeLockPeriod;
        s.stakes[_tokenId] = StakePosition({
            staker: msg.sender,
            stakedAt: block.timestamp,
            unlockTime: unlockTime,
            rewardClaimed: false
        });

        emit NFTStaked(msg.sender, _tokenId, unlockTime);
    }

    function unstakeNFT(uint256 _tokenId) external {
        StakePosition memory pos = s.stakes[_tokenId];
        require(pos.staker == msg.sender, "Staking: not staker");
        require(block.timestamp >= pos.unlockTime, "Staking: still locked");
        require(s.owners[_tokenId] == address(this), "Staking: token not held");

        delete s.stakes[_tokenId];

        _transferNFT(address(this), msg.sender, _tokenId);

        emit NFTUnstaked(msg.sender, _tokenId);
    }

    function claimReward(uint256 _tokenId) external {
        StakePosition storage pos = s.stakes[_tokenId];
        require(pos.staker == msg.sender, "Staking: not staker");
        require(block.timestamp >= pos.unlockTime, "Staking: still locked");
        require(!pos.rewardClaimed, "Staking: reward already claimed");

        uint256 reward = s.stakeRewardAmount;
        require(reward > 0, "Staking: reward not set");
        require(s.erc20Balances[address(this)] >= reward, "Staking: insufficient reward pool");

        pos.rewardClaimed = true;

        s.erc20Balances[address(this)] -= reward;
        s.erc20Balances[msg.sender] += reward;

        emit RewardClaimed(msg.sender, _tokenId, reward);
    }


    function stakeInfo(uint256 _tokenId)
        external
        view
        returns (address staker, uint256 stakedAt, uint256 unlockTime, bool rewardClaimed)
    {
        StakePosition memory pos = s.stakes[_tokenId];
        return (pos.staker, pos.stakedAt, pos.unlockTime, pos.rewardClaimed);
    }

    function rewardStatus(uint256 _tokenId) external view returns (bool claimable, bool claimed) {
        StakePosition memory pos = s.stakes[_tokenId];
        if (pos.staker == address(0)) return (false, false);
        claimed = pos.rewardClaimed;
        claimable = !pos.rewardClaimed && block.timestamp >= pos.unlockTime && s.stakeRewardAmount > 0;
    }

    function pendingReward(uint256 _tokenId) external view returns (uint256 amount) {
        StakePosition memory pos = s.stakes[_tokenId];
        if (pos.staker != address(0) && !pos.rewardClaimed && block.timestamp >= pos.unlockTime) {
            amount = s.stakeRewardAmount;
        }
    }

    function stakingConfig() external view returns (uint256 lockPeriod, uint256 rewardAmount) {
        return (s.stakeLockPeriod, s.stakeRewardAmount);
    }


    function _transferNFT(address _from, address _to, uint256 _tokenId) private {
        delete s.tokenApprovals[_tokenId];
        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }
}
