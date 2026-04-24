//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {TokenPool} from "../lib/chainlink-ccip/chains/evm/contracts/pools/TokenPool.sol";
import {Pool} from "../lib/chainlink-ccip/chains/evm/contracts/libraries/Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address _rnmProxy, address _router) TokenPool(_token, 18, _rnmProxy, _router) {}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurnIn(lockOrBurnIn);
        address receiver = abi.decode(lockOrBurnIn.receiver, (address));
        uint256 userInterestRate = IRebaseToken(address(i_token).getUserInterestRate(receiver));
        IRebaseToken(address(i_token).burn(address(this), lockOrBurnIn.amount));
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteTokenAddress(lockOrBurnIn.destChainSelector),
            destPoolData: abi.encode(userInterestRate),
        })
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMintIn(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.srcPoolData, (uint256));
        IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.amount, userInterestRate);
        return Pool.ReleaseOrMintOutV1({destTokenAddress: address(i_token)});
    }
}
