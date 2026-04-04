// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import 'chainlink-brownie-contracts/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol';
import "../libraries/AppStorage.sol";

contract VRFFacet {
    AppStorage internal s;

    bytes4 public constant EXTRA_ARGS_V1_TAG =
        bytes4(keccak256("VRF ExtraArgsV1"));
    error OnlyCoordinatorCanFulfill();

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    function getWords(uint256 _tokenId) external returns (uint256 requestId) {
        require(s.nftTraits[_tokenId].requestId == 0, "can't request twice");

        requestId = V2_5(s.reqData.vrfCoordinator).requestRandomWords(
            V2_5.RandomWordsRequest({
                keyHash: s.reqData.keyHash,
                subId: s.reqData.subscriptionId,
                requestConfirmations: s.reqData.requestConfirmations,
                callbackGasLimit: s.reqData.callbackGasLimit,
                numWords: s.reqData.numWords,
                extraArgs: _argsToBytes(
                    V2_5.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        s.requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        s.nftTraits[_tokenId].requestId = requestId;
        return requestId;
    }

    function rawFulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) external {
        if (msg.sender != s.reqData.vrfCoordinator) {
            revert OnlyCoordinatorCanFulfill();
        }

        s.requests[requestId].fulfilled = true;
        s.requests[requestId].randomWords = randomWords;
        emit RequestFulfilled(requestId, randomWords);
    }

    function _argsToBytes(
        V2_5.ExtraArgsV1 memory extraArgs
    ) internal pure returns (bytes memory bts) {
        return abi.encodeWithSelector(EXTRA_ARGS_V1_TAG, extraArgs);
    }
}

interface V2_5 {
    struct ExtraArgsV1 {
        bool nativePayment;
    }

    struct RandomWordsRequest {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bytes extraArgs;
    }

    function requestRandomWords(
        RandomWordsRequest memory r
    ) external returns (uint256 requestId);
}
