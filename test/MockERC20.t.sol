// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(uint256 initialSupply) ERC20("SampleToken", "STK") {
        _mint(msg.sender, initialSupply);
    }

    // Add a mint function
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
