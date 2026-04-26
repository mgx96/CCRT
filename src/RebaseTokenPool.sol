//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {TokenPool} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/pools/TokenPool.sol";
import {Pool} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/libraries/Pool.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address _rnmProxy, address _router)
        TokenPool(_token, 18, new address[](0), _rnmProxy, _router)
    {}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        public
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);
        address receiver = abi.decode(lockOrBurnIn.receiver, (address));
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(receiver);
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
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
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, localAmount, userInterestRate);
        return Pool.ReleaseOrMintOutV1({destinationAmount: localAmount});
    }
}
