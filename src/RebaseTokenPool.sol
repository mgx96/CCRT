//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {TokenPool} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/pools/TokenPool.sol";
import {Pool} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/libraries/Pool.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowList, address _rmnProxy, address _router)
        TokenPool(_token, 18, _allowList, _rmnProxy, _router)
    {}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        public
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);

        // Use originalSender (the source chain user), not the receiver
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);

        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(i_tokenDecimals, userInterestRate)
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        public
        override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        uint256 localAmount = _calculateLocalAmount(
            releaseOrMintIn.sourceDenominatedAmount, _parseRemoteDecimals(releaseOrMintIn.sourcePoolData)
        );
        _validateReleaseOrMint(releaseOrMintIn, localAmount);

        // Try to decode userInterestRate if sourcePoolData has the data, otherwise use 0
        uint256 userInterestRate = 0;
        if (releaseOrMintIn.sourcePoolData.length == 64) {
            // Assume format is (uint8 decimals, uint256 userInterestRate) = 32 + 32 bytes
            (, userInterestRate) = abi.decode(releaseOrMintIn.sourcePoolData, (uint8, uint256));
        }

        IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, localAmount, userInterestRate);
        return Pool.ReleaseOrMintOutV1({destinationAmount: localAmount});
    }
}
