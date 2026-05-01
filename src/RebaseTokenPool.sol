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

    /// @notice Override to burn RebaseToken through its interface
    function _lockOrBurn(uint256 amount) internal virtual override {
        IRebaseToken(address(i_token)).burn(address(this), amount);
    }

    /// @notice Override to mint RebaseToken with interest rate through its interface
    function _releaseOrMint(address receiver, uint256 amount) internal virtual override {
        IRebaseToken(address(i_token)).mint(receiver, amount, IRebaseToken(address(i_token)).getInterestRate());
    }
}
