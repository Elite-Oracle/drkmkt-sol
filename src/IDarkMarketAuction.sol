// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// INTERNAL IMPORTS
import "./IDarkMarketAuctionStructures.sol";

/// @title IDarkMarketAuction
/// @author Elite Oracle | Kristian Peter
/// @notice Interface to interact with the DarkMarketAuction contract.
/// @custom:version 1.3.2
/// @custom:release October 2023
interface IDarkMarketAuction is IDarkMarketAuctionStructures {

    // =============== //
    // STATE VARIABLES //
    // =============== //

    /*******************
     * Auction-related *
     *******************/

    /// @notice Counter for the next auction ID
    function nextAuctionId() external returns (uint256);

    /// @notice Mapping from auction ID to its details
    function auctions(uint256 auctionId) external returns (Auction);

    /// @notice Failed transfers
    function pendingWithdrawals(address wallet) external returns (PendingWithdrawal);

    /*********************
     * Parameter-related *
     *********************/

    /// @notice Minimum auction duration
    function minAuctionDuration() external returns (uint256);

    /// @notice Minimum auction duration
    function maxAuctionDuration() external returns (uint256);

    /// @notice Warm-up time to be used to discourage bots from placing arbitrary opening bids
    function warmUpTime() external returns (uint256);

    /// @notice Extra time added to the auction if a bid is placed in the last minutes of the bidding. This helps prevent
    ///         auction sniping and gives other participants a chance to place their bids.
    function extraTime() external returns (uint256);

    /// @notice Maximum bidder incentive in percentage (12%)
    function maxIncentive() external returns (uint256);

    /// @notice The maximum payment paid out of the auction is 10% and this is represented by 10^3.
    function maxPayment() external returns (uint256);

    /// @notice The maximum number of Assets that can be sold in One Auction.
    function maxAssets() external returns (uint256);



    // ====== //
    // EVENTS //
    // ====== //

    /*******************
     * Auction-related *
     *******************/

    /// @notice Auction has started.
    event AuctionStarted(uint256 auctionId, address seller, uint256 startPrice, uint32 endTime);
    /// @notice Bid is placed.
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount, uint256 incentive, uint32 endTime);
    /// @notice Auction is finalized.
    event SellerFinalized(uint256 auctionId, address seller, uint256 amount);
    /// @notice Auction is finalized.
    event BidderFinalized(uint256 auctionId, address winner, uint256 amount);
    /// @notice Auction is finalized.
    event OwnerFinalized(uint256 auctionId, address owner, uint256 fee, address royaltyAddress, uint256 royalty);
    /// @notice Auction is cancelled.
    event AuctionCancelled(uint256 auctionId);
    /// @notice Incentive is received
    event IncentiveReceived(address indexed bidder, uint256 amount);

    /*********************
     * Parameter-related *
     *********************/

    // @notice Minimum auction duration has been updated
    event MinAuctionDurationUpdated(uint32 newDuration);
    // @notice Maximum auction duration has been updated
    event MaxAuctionDurationUpdated(uint32 newDuration);
    // @notice Maximum auction incentive has been updated
    event MaxIncentiveUpdated(uint16 newIncentive);
    // @notice Warm-up time has been updated
    event WarmUpTimeUpdated(uint32 newWarmUp);
    // @notice Maximum payment has been updated
    event MaxPaymentUpdated(uint32 newMaxPmt);
    // @notice Extra time has been updated
    event ExtraTimeUpdated(uint32 newExtraTime);
    // @notice Maximum asset count has been updated
    event MaxAssetsUpdated(uint32 newMaxAssets);
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
    error InvalidExtraTime(uint256 extraTime, address max);

    // ================= //
    // AUCTION FUNCTIONS //
    // ================= //

    /// @notice Starts an auction by transferring the ERC721 tokens into the contract.
    /// @param startPrice The starting price for the auction.
    /// @param duration The duration of the auction in seconds (86,400 = 1 day).
    /// @param _tokens The array of TokenDetail containing the ERC721 contract addresses and token IDs.
    /// @param ERC20forBidding The address of the ERC20 token used for bidding.
    /// @param _fees The fees and address for royalties.
    /// @return The ID of the newly created auction.
    function startAuction(
        uint256 startPrice,
        uint32 duration,
        TokenDetail[] memory _tokens,
        address ERC20forBidding,
        FeeDetail memory _fees
    ) external returns (uint256);

    /// @notice Allows users to place bids on an auction.
    /// @param auctionId The ID of the auction.
    /// @param bidAmount The bid amount.
    /// @param incentiveAmount The bidder incentive.
    function bid(uint256 auctionId, uint256 bidAmount, uint256 incentiveAmount) external;

    /// @dev Finalizes an auction, handling transfers to the seller, highest bidder, and owner. Depending on the caller,
    ///      different transfers are executed.
    /// @param auctionId The ID of the auction to finalize.
    function finalizeAuction(uint256 auctionId) external;

    /// @dev Allows users to withdraw their funds if a transfer failed during finalizeAuction.
    function withdrawPending() external;

    /// @dev Failsafe function to cancel a specific auction by the contract owner.
    /// @param auctionId The ID of the auction.
    function cancelSpecificAuction(uint256 auctionId) external;

    /// @dev Allows the contract owner to set the minimum auction duration.
    /// @param _duration The new minimum auction duration.
    function setMinAuctionDuration(uint32 _duration) external;

    /// @dev Allows the contract owner to set the maximum auction duration.
    /// @param _duration The new maximum auction duration.
    function setMaxAuctionDuration(uint32 _duration) external;

    /// @dev Allows the contract owner to set the maximum number of assets allowed in each auction.
    /// @param _assets The new minimum auction duration.
    function setMaxAssets(uint16 _assets) external;

    /// @dev Allows the contract owner to set the maximum incentive.
    /// @param _incentive The new maximum incentive in percentage.
    function setMaxIncentive(uint16 _incentive) external;

    /// @dev Allows the contract owner to set the warm-up time.
    /// @param _warmUp The new warm-up time.
    function setWarmUpTime(uint32 _warmUp) external;

    /// @dev Allows the contract owner to set the extra time added when a bidder places a bid in the final minutes of an
    ///      auction. Only allowed to be 12 hours maximum.
    /// @param _extraTime The new extra auction time.
    function setExtraTime(uint32 _extraTime) external;

    /// @dev Allows the contract owner to set the maximum payment for contract fees and royalties. 10% is the maximum
    ///      and the scale is 10^3 (1000 = 10%).
    /// @param _maxPmt The new warm-up time.
    function setMaxPayment(uint16 _maxPmt) external;

    /// @dev Returns the Status of active auctions.
    /// @return The Status of active auctions.
    function getAuctionStatus(uint256 auctionId) external view returns (AuctionStatus);

    /// @dev Returns the end time of the auction.
    /// @return The end time of the current auction.
    function getAuctionEndTime(uint256 auctionId) external view returns (uint32);

    /// @dev Allows the Seller to cancel the auction if no bids have been placed.
    /// @param auctionId The ID of the auction.
    function cancelAuction(uint256 auctionId) external;
}
