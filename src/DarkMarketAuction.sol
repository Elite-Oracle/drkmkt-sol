// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// IMPORTS
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DarkMarketAuction
 * @dev This contract allows users to start, bid, and finalize auctions for a variety of ERC tokens (digital assets).
 * @author Elite Oracle | Kristian Peter
 * October 2023 | Version 1.3.2
 */
contract DarkMarketAuction is ERC721Holder, Ownable, Pausable, ReentrancyGuard {

    // ============================
    // DATA STRUCTURES
    // ============================

    // Represents the Contract Address and Token ID for every ERC721 token
    struct TokenDetail {
        address tokenAddress;
        uint256 tokenId;
    }

    // Represents the Contract Fees for every auction
    struct FeeDetail {
        uint256 contractFee; // Fee charged for auction
        uint256 royaltyFee; // Royalty Fee
        address royaltyAddress; // Token Creator
    }

    // Represents an auction for ERC721 tokens
    struct Auction {
        address payable seller;           // Address of the seller
        uint32 startTime;                 // Start time of the auction
        uint32 endTime;                   // End time of the auction
        address highestBidder;            // Address of the current highest bidder
        uint256 highestBid;               // Amount of the current highest bid
        uint256 bidderIncentive;          // Incentive for the bidder
        AuctionStatus status;             // Status of the auction (Open, PreBid, Bid, ExtraTime, Finalized)
        TokenDetail[] tokens;         // Array of ERC721 tokens
        address bidTokenAddress;          // ERC20 token address used for bidding
        uint256 totalIncentives;    // Total incentives paid to bidders who are outbid
        FeeDetail fees;           // Array of fees for contract and royalties
    }

    // Represents the status of an auction
    enum AuctionStatus {
        Open,
        BidReceived,
        ExtraTime,
        Closed,
        Cancelled
    }

    // Mapping to store both amount and ERC20 token address in the case of a Failed Transaction
    struct PendingWithdrawal {
        uint256 amount;
        address tokenAddress;
    }

    // ============================
    // STATE VARIABLES
    // ============================

    // Auction-related
    uint256 public nextAuctionId = 1; // Counter for the next auction ID
    mapping(uint256 => Auction) public auctions;  // Mapping from auction ID to its details

    // Auction parameters
    uint32 public minAuctionDuration = 1 minutes;  // Minimum auction duration
    uint32 public maxAuctionDuration = 12 weeks;  // Minimum auction duration
    uint32 public warmUpTime = 0 minutes;  // Warm-up time to be used to discourage bots from placing arbitrary opening bids
    uint32 public Extra_Time = 0 minutes;     // Extra time added to the auction if a bid is placed in the last minutes of the bidding. This helps prevent auction sniping and gives other participants a chance to place their bids.
    uint16 public Max_Incentive = 12;  // Maximum bidder incentive in percentage (12%)
    uint16 public Max_Payment = 1000;     // The maximum payment paid out of the auction is 10% and this is represented by 10^3.
    uint16 public Max_Assets = 20;     // The maximum number of Assets that can be sold in One Auction.

    // Failed transfers
    mapping(address => PendingWithdrawal) public pendingWithdrawals;

    // ============================
    // EVENTS
    // ============================

    // Auction-related events
    event AuctionStarted(uint256 auctionId, address seller, uint256 startPrice, uint32 endTime);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount, uint256 incentive, uint32 endTime);
    event SellerFinalized(uint256 auctionId, address seller, uint256 amount);    
    event BidderFinalized(uint256 auctionId, address winner, uint256 amount);    
    event OwnerFinalized(uint256 auctionId, address owner, uint256 fee, address royaltyAddress, uint256 royalty);
    event AuctionCancelled(uint256 auctionId);
    event IncentiveReceived(address indexed bidder, uint256 amount);

    // Parameter update events
    event MinAuctionDurationUpdated(uint32 newDuration);
    event MaxAuctionDurationUpdated(uint32 newDuration);
    event MaxIncentiveUpdated(uint16 newIncentive);
    event WarmUpTimeUpdated(uint32 newWarmUp);
    event MaxPaymentUpdated(uint32 newMaxPmt);
    event ExtraTimeUpdated(uint32 newExtraTime);
    event MaxAssetsUpdated(uint32 newMaxAssets);
    event TransferFailed(address tokenAddress, address to, uint256 tokenId);

    // ============================
    // AUCTION FUNCTIONS
    // ============================

    /**
     * @notice Starts an auction by transferring the ERC721 tokens into the contract.
     * @param startPrice The starting price for the auction.
     * @param duration The duration of the auction in seconds (86,400 = 1 day).
     * @param _tokens The array of TokenDetail containing the ERC721 contract addresses and token IDs.
     * @param ERC20forBidding The address of the ERC20 token used for bidding.
     * @param _fees The fees and address for royalties.
     * @return The ID of the newly created auction.
     */
    function startAuction(
        uint256 startPrice,
        uint32 duration,
        TokenDetail[] memory _tokens, 
        address ERC20forBidding,
        FeeDetail memory _fees
    ) external whenNotPaused returns (uint256) {
        require(_tokens.length > 0 && _tokens.length <= Max_Assets, "Invalid number of tokens for the auction");
        require(duration >= minAuctionDuration && duration <= maxAuctionDuration, "Invalid auction duration");
        require(_fees.contractFee <= Max_Payment && _fees.royaltyFee <= Max_Payment, "Fee percentage too high");

        // Initialize a new auction
        Auction storage newAuction = auctions[nextAuctionId];
        newAuction.seller = payable(msg.sender);
        newAuction.startTime = uint32(block.timestamp);
        newAuction.endTime = uint32(block.timestamp + duration);
        newAuction.highestBid = startPrice;
        newAuction.status = AuctionStatus.Open;
        newAuction.bidTokenAddress = ERC20forBidding;
        newAuction.fees = _fees;

        // Transfer each ERC721 token to the contract
        for (uint i = 0; i < _tokens.length; i++) {
            IERC721(_tokens[i].tokenAddress).safeTransferFrom(msg.sender, address(this), _tokens[i].tokenId);
            newAuction.tokens.push(_tokens[i]);
        }

        emit AuctionStarted(nextAuctionId, msg.sender, startPrice, newAuction.endTime);
        nextAuctionId++;

        return nextAuctionId - 1;
    }

    /**
     * @notice Allows users to place bids on an auction.
     * @param auctionId The ID of the auction.
     * @param bidAmount The bid amount.
     * @param incentiveAmount The bidder incentive.
     */
    function bid(uint256 auctionId, uint256 bidAmount, uint256 incentiveAmount) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp <= auction.endTime, "Auction has ended");
        require(bidAmount > auction.highestBid, "Bid amount must be greater than the current highest bid");
        require(incentiveAmount <= (Max_Incentive * bidAmount) / 100, "Bidder incentive too high");

        IERC20 bidToken = IERC20(auction.bidTokenAddress);
        require(bidToken.transferFrom(msg.sender, address(this), bidAmount), "Token transfer failed");

        // Check for extra time condition
        if (block.timestamp > auction.endTime - Extra_Time) {
            auction.endTime += Extra_Time;
            auction.status = AuctionStatus.ExtraTime;
        } else {
            auction.status = AuctionStatus.BidReceived;
        }

        // Refund previous bidder if applicable
        if (auction.highestBidder != address(0) && block.timestamp >= auction.startTime + warmUpTime) {
            uint256 refundAmount = auction.highestBid + auction.bidderIncentive;
            bidToken.transfer(auction.highestBidder, refundAmount);
            auction.totalIncentives += incentiveAmount;
            emit IncentiveReceived(auction.highestBidder, auction.bidderIncentive);
        } else if (auction.highestBidder != address(0)) {
            bidToken.transfer(auction.highestBidder, auction.highestBid);
        }

        // Update auction details
        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount;
        auction.bidderIncentive = incentiveAmount;

        emit BidPlaced(auctionId, auction.highestBidder, auction.highestBid, auction.bidderIncentive, auction.endTime);
    }

    /** Cancel Auction (Seller)
     * @dev Allows the Seller to cancel the auction if no bids have been placed.
     * @param auctionId The ID of the auction.
     */
    function cancelAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];
        require(msg.sender == auction.seller || msg.sender == address(this), "Auctions can only be Cancelled by the Seller"); // Seller can cancel auction if no bids received or contract can finalize auction and cancel if no bids were received.
        require(auction.status == AuctionStatus.Open || msg.sender == address(this), "Auction has received bids and cannot be canceled"); // If bids have been made on the auction it cannot be cancelled by the Seller

        // Transfer all tokens back to the seller
        for (uint i = 0; i < auction.tokens.length; i++) {
            IERC721(auction.tokens[i].tokenAddress).transferFrom(
                address(this),
                auction.seller,
                auction.tokens[i].tokenId
            );
        }

        auction.status = AuctionStatus.Cancelled;

        emit AuctionCancelled(auctionId);
    }

/**
 * @dev Finalizes an auction, handling transfers to the seller, highest bidder, and owner.
 * Depending on the caller, different transfers are executed.
 * @param auctionId The ID of the auction to finalize.
 */
function finalizeAuction(uint256 auctionId) external nonReentrant whenNotPaused {
    Auction storage auction = auctions[auctionId];
    require(block.timestamp >= auction.endTime, "Auction has not Ended");

    // If there are no bids, cancel the auction.
    if (auction.highestBidder == address(0)) {
        cancelAuction(auctionId);
    }

    IERC20 bidToken = IERC20(auction.bidTokenAddress);

    // If the caller is the seller or the owner
    if (msg.sender == auction.seller) {
        uint256 fee = auction.highestBid * (auction.fees.contractFee / 10000);
        uint256 royalty = auction.highestBid * (auction.fees.royaltyFee / 10000);
        uint256 sellerAmount = auction.highestBid - fee - royalty - auction.totalIncentives;

        // Safely transfer winning bid to Seller minus incentives and fees
        safeTransfer(bidToken, auction.seller, sellerAmount);

        emit SellerFinalized(auctionId, auction.seller, sellerAmount);
    }

    // If the caller is the highest bidder or the owner
    if (msg.sender == auction.highestBidder) {
        // Safely transfer all auctioned tokens to the highest bidder
        for (uint i = 0; i < auction.tokens.length; i++) {
            IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(address(this), auction.highestBidder, auction.tokens[i].tokenId);
        }

        emit BidderFinalized(auctionId, auction.highestBidder, auction.highestBid);
    }

    // If the caller is the owner
    if (msg.sender == owner()) {
        uint256 fee = auction.highestBid * (auction.fees.contractFee / 10000);
        uint256 royalty = auction.highestBid * (auction.fees.royaltyFee / 10000);

        // Safely transfer Fees to Owner
        safeTransfer(bidToken, owner(), fee);

        // Safely transfer Royalty Fees to Creator
        safeTransfer(bidToken, auction.fees.royaltyAddress, royalty);

        emit OwnerFinalized(auctionId, owner(), fee, auction.fees.royaltyAddress, royalty);
    }
}

/**
 * @dev Safely transfers tokens, adding to pending withdrawals if the transfer fails.
 * @param token The ERC20 token to transfer.
 * @param to The address to transfer to.
 * @param amount The amount to transfer.
 */
function safeTransfer(IERC20 token, address to, uint256 amount) internal {
    try token.transfer(to, amount) {
        // Transfer successful
    } catch {
        // If transfer fails, add to pending withdrawals
        pendingWithdrawals[to].amount += amount;
        pendingWithdrawals[to].tokenAddress = address(token);
    }
}

/**
 * @dev Allows users to withdraw their funds if a transfer failed during finalizeAuction.
 */
function withdrawPending() external {
    uint256 amount = pendingWithdrawals[msg.sender].amount;
    address tokenAddress = pendingWithdrawals[msg.sender].tokenAddress;

    require(amount > 0, "No funds to withdraw");
    require(tokenAddress != address(0), "Invalid token address");

    pendingWithdrawals[msg.sender].amount = 0;
    pendingWithdrawals[msg.sender].tokenAddress = address(0);

    IERC20(tokenAddress).transfer(msg.sender, amount);
}

    /** Cancel Specific Auction (Owner)
    * @dev Failsafe function to cancel a specific auction by the contract owner.
    * @param auctionId The ID of the auction.
    */
    function cancelSpecificAuction(uint256 auctionId) external onlyOwner {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction does not exist");

        if (auction.highestBidder != address(0)) {
        IERC20(auction.bidTokenAddress).transfer(auction.highestBidder, auction.highestBid - auction.totalIncentives);
    }

    for (uint i = 0; i < auction.tokens.length; i++) {
        IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(address(this), auction.seller, auction.tokens[i].tokenId);
    }

    auction.status = AuctionStatus.Cancelled;

    emit AuctionCancelled(auctionId);
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /** Get Auction Status
    * @dev Returns the Status of active auctions.
    * @return The Status of active auctions.
    */
    function getAuctionStatus(uint256 auctionId) external view returns (AuctionStatus) {
        return auctions[auctionId].status;
    }

    /** Get Auction End Time
    * @dev Returns the end time of the auction.
    * @return The end time of the current auction.
    */
    function getAuctionEndTime(uint256 auctionId) external view returns (uint32) {
    return auctions[auctionId].endTime;
    }

    /** This function gets executed if a transaction with invalid data is sent to the contract or just ether without data. We revert the send in both cases.
    */
    fallback() external payable {
        revert("DarkMarketAuction: Invalid or unexpected call");
    }
    // Function to receive Ether. msg.data must be empty
    receive() external payable {
        revert("DarkMarketAuction: Ether not accepted");
    }

/**
 * @dev Allows the contract owner to set the minimum auction duration.
 * @param _duration The new minimum auction duration.
 */
function setMinAuctionDuration(uint32 _duration) external onlyOwner {
    require(_duration >= 1 minutes, "Minimum Auction Duration must be longer than 1 minute");
    minAuctionDuration = _duration;
    emit MinAuctionDurationUpdated(_duration);
}

/**
 * @dev Allows the contract owner to set the maximum auction duration.
 * @param _duration The new maximum auction duration.
 */
function setMaxAuctionDuration(uint32 _duration) external onlyOwner {
    require(_duration <= 52 weeks, "Maximum Auction Duration must be less than 1 year");
    maxAuctionDuration = _duration;
    emit MaxAuctionDurationUpdated(_duration);
}

/** Set Max Assets (only owner)
 * @dev Allows the contract owner to set the maximum number of assets allowed in each auction.
 * @param _assets The new minimum auction duration.
 */
function setMaxAssets(uint16 _assets) external onlyOwner {
    require(_assets <= 100, "Maximum Number of Assets in an Auction must be less than 100");
    Max_Assets = _assets;
    emit MaxAssetsUpdated(_assets);
}

/**
 * @dev Allows the contract owner to set the maximum incentive.
 * @param _incentive The new maximum incentive in percentage.
 */
function setMaxIncentive(uint16 _incentive) external onlyOwner {
    require(_incentive <= 100, "Incentive cannot be more than 100%");
    Max_Incentive = _incentive;
    emit MaxIncentiveUpdated(_incentive);
}

/**
 * @dev Allows the contract owner to set the warm-up time.
 * @param _warmUp The new warm-up time.
 */
function setWarmUpTime(uint32 _warmUp) external onlyOwner {
    warmUpTime = _warmUp;
    emit WarmUpTimeUpdated(_warmUp);
}

/** Set Extra Time (Only Owner)
 * @dev Allows the contract owner to set the extra time added when a bidder places a bid in the final minutes of an auction. Only allowed to be 12 hours maximum.
 * @param _extraTime The new extra auction time.
 */
function setExtraTime(uint32 _extraTime) external onlyOwner {
    require(_extraTime <= 12 hours);
    Extra_Time = _extraTime;
    emit ExtraTimeUpdated(_extraTime);
}

/** Set Max Payment (Only Owner)
 * @dev Allows the contract owner to set the maximum payment for contract fees and royalties. 10% is the maximum and the scale is 10^3 (1000 = 10%).
 * @param _maxPmt The new warm-up time.
 */
function setMaxPayment(uint16 _maxPmt) external onlyOwner {
    require(_maxPmt <= 1000, "Fees must be below 10%");
    Max_Payment = _maxPmt;
    emit MaxPaymentUpdated(_maxPmt);
}
}
