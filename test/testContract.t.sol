// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DarkMarketAuction.sol";
import "./MockERC20.t.sol";
import "./MockERC721.t.sol";
import "./MockERC1155.t.sol";

contract DarkMarketAuctionTest is Test {
    DarkMarketAuction public auctionContract;
    MockERC20 public erc20;
    MockERC721 public erc721;
    MockERC1155 public erc1155;

    address user1 = address(1);
    address user2 = address(2);
    address user3 = address(3);

    function setUp() public {
        // Deploy the auction contract
        auctionContract = new DarkMarketAuction();
        auctionContract.initialize();

        // Deploy mock tokens
        erc20 = new MockERC20(1000000);
        erc721 = new MockERC721("Mock ERC721", "MERC721");
        erc1155 = new MockERC1155("Mock ERC1155");

        // Mint and approve for each user
        mintAndApprove(user1, 1, 1000 ether, 10);
        mintAndApprove(user2, 2, 500 ether, 20);
        mintAndApprove(user3, 3, 250 ether, 30);
    }

    function mintAndApprove(address user, uint256 tokenId, uint256 erc20Amount, uint256 erc1155Amount) internal {
        // Mint tokens
        vm.prank(user);
        erc20.mint(user, erc20Amount);
        erc721.mint(user, tokenId);
        erc1155.mint(user, tokenId, erc1155Amount, "");

        // Approve the auction contract to spend tokens on behalf of the user
        vm.prank(user);
        erc20.approve(address(auctionContract), erc20Amount);
        erc721.setApprovalForAll(address(auctionContract), true);
        erc1155.setApprovalForAll(address(auctionContract), true);
    }
}
