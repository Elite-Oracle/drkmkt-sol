// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// INTERNAL IMPORTS
import "./IDarkMarketAuctionStructures.sol";

/// @title IDarkMarketAuction
/// @author Elite Oracle | Kristian Peter
/// @notice Interface to interact with the DarkMarketAuction contract.
/// @custom:version 1.4.1
/// @custom:release November 2023
interface IDarkMarketAuction is IDarkMarketAuctionStructures {

    // ====== //
    // EVENTS //
    // ====== //

    /*******************
     * Auction-related *
     *******************/

    /// @notice Auction has started.
    event AuctionStarted(uint256 auctionId, address seller, uint256 startPrice, uint256 endTime);
    /// @notice Bid is placed.
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount, uint256 incentive, uint256 endTime);
    /// @notice Auction is finalized.
    event SellerFinalized(uint256 auctionId, address seller, uint256 amount);
    /// @notice Auction is finalized.
    event BidderFinalized(uint256 auctionId, address winner, uint256 amount);
    /// @notice Auction is finalized.
    event AuctionFinalized(uint256 auctionId, uint256 fee, address royaltyAddress, uint256 royalty);
    /// @notice Auction is cancelled.
    event AuctionCancelled(uint256 auctionId);
    /// @notice Incentive is received
    event IncentiveReceived(address indexed bidder, uint256 amount);

    /*********************
     * Parameter-related *
     *********************/

    // @notice Minimum auction duration has been updated
    event MinAuctionDurationUpdated(uint256 newDuration);
    // @notice Maximum auction duration has been updated
    event MaxAuctionDurationUpdated(uint256 newDuration);
    // @notice Maximum auction incentive has been updated
    event MaxIncentiveUpdated(uint16 newIncentive);
    // @notice Warm-up time has been updated
    event WarmUpTimeUpdated(uint256 newWarmUp);
    // @notice Maximum payment has been updated
    event MaxPaymentUpdated(uint256 newMaxPmt);
    // @notice Extra time has been updated
    event ExtraTimeUpdated(uint256 newExtraTime);
    // @notice Maximum asset count has been updated
    event MaxAssetsUpdated(uint256 newMaxAssets);
    // @notice Treasury address updated
    event TreasuryUpdated(address newTreasury);
    // @notice Transfer of asset failed
    event TransferFailed(address tokenAddress, address to, uint256 tokenId);

    // ====== //
    // ERRORS //
    // ====== //

    /// @notice Asset count is greater than the maximum allowed or zero
    error InvalidAAssetCount(uint256 count, uint256 max);
    /// @notice Auction duration is less than the minimum or greater than the maximum
    error InvalidAuctionDuration(uint256 duration, uint256 min, uint256 max);
    /// @notice Auction fee percentage is too high
    error InvalidAuctionFeePercentage(uint256 fee, uint256 max);
    /// @notice Royalty fee percentage is too high
    error InvalidRoyaltyFeePercentage(uint256 fee, uint256 max);
    /// @notice Incentive is too high
    error IncentiveTooHigh(uint256 incentiveAmount, uint256 maxIncentive);
    /// @notice Auction has not been created
    error InvalidAuction(uint256 auctionId);
    /// @notice Auction has been created but not started
    error AuctionNotStarted(uint256 now, uint256 endTime);
    /// @notice Bids have been made on the auction it cannot be cancelled by the Seller
    error AuctionHasBids();
    /// @notice Auction has not ended it cannot be finalized
    error AuctionNotEnded(uint256 now, uint256 endTime);
    /// @notice Auction has ended it cannot be cancelled by the Seller
    error AuctionEnded(uint256 now, uint256 endTime);
    /// @notice Bid is too low to outbid the current highest bid
    error BidTooLow(uint256 bidAmount, uint256 highestBid);
    /// @notice Sender is not the seller
    error NotAuctionSeller(address seller, address msgSender);
    /// @notice Current accrued fees are empty
    error NoFeesRemaining();
    /// @notice Attempt to withdraw without fee token having been set
    error FeeTokenNotConfigured();
    /// @notice Extra time is too long
    error InvalidExtraTime(uint256 extraTime, uint256 max);

    // ================= //
    // AUCTION FUNCTIONS //
    // ================= //

    /// @notice Starts an auction by transferring the ERC721 tokens into the contract.
    /// @param startPrice The starting price for the auction.
    /// @param duration The duration of the auction in seconds (86,400 = 1 day).
    /// @param _tokens The array of TokenDetail containing the ERC721 contract addresses and token IDs.
    /// @param ERC20forBidding The address of the ERC20 token used for bidding.
    /// @param _fees The fees and address for royalties.
    function startAuction(
        uint256 startPrice,
        uint256 duration,
        TokenDetail[] calldata _tokens,
        address ERC20forBidding,
        FeeDetail calldata _fees
    ) external;

    /// @notice Allows users to place bids on an auction.
    /// @param auctionId The ID of the auction.
    /// @param bidAmount The bid amount.
    /// @param incentiveAmount The bidder incentive.
    function bid(uint256 auctionId, uint256 bidAmount, uint256 incentiveAmount) external;

    /// @dev Finalizes an auction, handling transfers to the seller, highest bidder, and owner. Depending on the caller,
    ///      different transfers are executed.
    /// @param auctionId The ID of the auction to finalize.
    function finalizeAuction(uint256 auctionId) external;

    /// @dev Failsafe function to cancel a specific auction by the contract owner.
    /// @param auctionId The ID of the auction.
    function cancelSpecificAuction(uint256 auctionId) external;

    /// @dev Allows the contract owner to set the minimum auction duration.
    /// @param _duration The new minimum auction duration.
    function setMinAuctionDuration(uint256 _duration) external;

    /// @dev Allows the contract owner to set the maximum auction duration.
    /// @param _duration The new maximum auction duration.
    function setMaxAuctionDuration(uint256 _duration) external;

    /// @dev Allows the contract owner to set the maximum number of assets allowed in each auction.
    /// @param _assets The new minimum auction duration.
    function setMaxAssets(uint16 _assets) external;

    /// @dev Allows the contract owner to set the maximum incentive.
    /// @param _incentive The new maximum incentive in percentage.
    function setMaxIncentive(uint16 _incentive) external;

    /// @dev Allows the contract owner to set the warm-up time.
    /// @param _warmUp The new warm-up time.
    function setWarmUpTime(uint256 _warmUp) external;

    /// @dev Allows the contract owner to set the extra time added when a bidder places a bid in the final minutes of an
    ///      auction. Only allowed to be 12 hours maximum.
    /// @param _extraTime The new extra auction time.
    function setExtraTime(uint256 _extraTime) external;

    /// @dev Allows the contract owner to set the maximum payment for contract fees and royalties. 10% is the maximum
    ///      and the scale is 10^3 (1000 = 10%).
    /// @param _maxPmt The new warm-up time.
    function setMaxPayment(uint256 _maxPmt) external;

    /// @dev Allows the contract owner to set the Treasury address
    /// @param _treasury The new treasury address
    function setTreasury(address _treasury) external;

    /// @dev Allows the Seller to cancel the auction if no bids have been placed.
    /// @param auctionId The ID of the auction.
    function cancelAuction(uint256 auctionId) external;
}
