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
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMintIn(releaseOrMintIn);
    }
}
