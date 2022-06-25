// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PVEBonusesPool is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public _token;

    constructor(address token) {
        _token = IERC20(token);
    }

    function approve(address from, uint256 amount) public onlyOwner {
        _token.safeApprove(from, amount);
    }

    function increaseAllowance(address from, uint256 amount) public onlyOwner {
        _token.safeIncreaseAllowance(from, amount);
    }

    function decreaseAllowance(address from, uint256 amount) public onlyOwner {
        _token.safeDecreaseAllowance(from, amount);
    }
}
