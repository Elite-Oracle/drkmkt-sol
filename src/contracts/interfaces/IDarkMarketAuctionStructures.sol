// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IDarkMarketAuctionStructures
/// @author Elite Oracle | Kristian Peter
/// @notice Interface to hold the global data structures for the DarkMarketAuction contract.
/// @custom:version 1.3.2
/// @custom:release October 2023
interface IDarkMarketAuctionStructures {

    /// @notice Represents the status of an auction
    enum AuctionStatus {Open, BidReceived, ExtraTime, Closed, Cancelled}

    /// @notice Represents the Contract Address, Token ID, and additional details for every token (ERC721 or ERC1155)
    /// @custom:member address tokenAddress The address of the token (ERC721 or ERC1155)
    /// @custom:member uint256 tokenId The ID of the token
    /// @custom:member uint256 tokenQuantity The quantity of the token (relevant for ERC1155)
    /// @custom:member bool isERC1155 A flag to indicate if the token is ERC1155 (true) or ERC721 (false)
    enum TokenType {ERC721, ERC1155}

    struct TokenDetail {
        address tokenAddress;
        uint256 tokenId;
        uint256 tokenQuantity;
        TokenType tokenType;
    }

    /// @notice Represents the Contract Fees for every auction
    /// @custom:member uint256 contractFee The fee charged for the auction
    /// @custom:member uint256 royaltyFee The royalty fee
    /// @custom:member address royaltyAddress The address of the royalty recipient
    struct FeeDetail {
        uint256 contractFee;
        uint256 royaltyFee;
        address royaltyAddress;
    }

    /// @notice Represents an auction for ERC721 tokens
    /// @custom:member address payable seller The address of the seller
    /// @custom:member uint32 startTime The start time of the auction
    /// @custom:member uint32 endTime The end time of the auction
    /// @custom:member address highestBidder The address of the current highest bidder
    /// @custom:member uint256 highestBid The amount of the current highest bid
    /// @custom:member uint256 bidderIncentive The incentive for the bidder
    /// @custom:member AuctionStatus status The status of the auction (Open, PreBid, Bid, ExtraTime, Finalized)
    /// @custom:member TokenDetail[] tokens The array of ERC721 tokens
    /// @custom:member address bidTokenAddress The ERC20 token address used for bidding
    /// @custom:member uint256 totalIncentives The total incentives paid to bidders who are outbid
    /// @custom:member FeeDetail fees The fees for contract and royalties
    struct Auction {
        address payable seller;
        address highestBidder;
        address bidTokenAddress;
        uint256 startTime;
        uint256 endTime;
        uint256 highestBid;
        uint256 bidderIncentive;
        uint256 totalIncentives;
        AuctionStatus status;
        FeeDetail fees;
        TokenDetail[] tokens;
    }
}
