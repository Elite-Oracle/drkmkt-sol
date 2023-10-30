// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// EXTERNAL IMPORTS
import {ERC721HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// INTERNAL IMPORTS
import {IDarkMarketAuction} from "./IDarkMarketAuction.sol";
import {AddressBook} from "./lib/AddressBook.sol";

/// @title DarkMarketAuction
/// @author Elite Oracle | Kristian Peter
/// @notice This contract allows users to start, bid, and finalize auctions for a variety of ERC tokens (digital assets)
/// @custom:version 1.3.2
/// @custom:release October 2023
contract DarkMarketAuction is IDarkMarketAuction, Initializable, ERC721HolderUpgradeable, AccessManagedUpgradeable,
PausableUpgradeable, ReentrancyGuardUpgradeable {

    // =============== //
    // STATE VARIABLES //
    // =============== //

    /*******************
     * Auction-related *
     *******************/

    /// @inheritdoc nextAuctionId
    uint256 public nextAuctionId;
    /// @inheritdoc auctions
    mapping(uint256 => Auction) public auctions;

    /// @inheritdoc pendingWithdrawals
    mapping(address => PendingWithdrawal) public pendingWithdrawals;

    /*********************
     * Parameter-related *
     *********************/

    /// @inheritdoc minAuctionDuration
    uint32 public minAuctionDuration;
    /// @inheritdoc maxAuctionDuration
    uint32 public maxAuctionDuration;
    /// @inheritdoc warmUpTime
    uint32 public warmUpTime;
    /// @inheritdoc extraTime
    uint32 public extraTime;
    /// @inheritdoc maxIncentive
    uint16 public maxIncentive;
    /// @inheritdoc maxPayment
    uint16 public maxPayment;
    /// @inheritdoc maxAssets
    uint16 public maxAssets;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721Holder_init();
        __Pausable_init();
        __AccessManaged_init(AddressBook.accessManager());
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();


        nextAuctionId = 1;
        minAuctionDuration = 1 minutes;
        maxAuctionDuration = 12 weeks;
        warmUpTime = 0 minutes;
        extraTime = 0 minutes;
        maxIncentive = 12;
        maxPayment = 1000;
        maxAssets = 20;
    }

    // ============================
    // AUCTION FUNCTIONS
    // ============================

    /// @inheritdoc startAuction
    function startAuction(
        uint256 startPrice,
        uint32 duration,
        TokenDetail[] memory _tokens,
        address ERC20forBidding,
        FeeDetail memory _fees
    ) external whenNotPaused returns (uint256) {
        if (_tokens.length == 0 || _tokens.length > maxAssets) revert InvalidAAssetCount(_tokens.length, maxAssets);
        if (duration < minAuctionDuration || duration > maxAuctionDuration)
            revert InvalidAuctionDuration(duration, minAuctionDuration, maxAuctionDuration);
        if (_fees.contractFee > maxPayment) revert InvalidAuctionFeePercentage(_fees.contractFee, maxPayment);
        if (_fees.royaltyFee > maxPayment) revert InvalidAuctionFeePercentage(_fees.royaltyFee, maxPayment);

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

    /// @inheritdoc bid
    function bid(uint256 auctionId, uint256 bidAmount, uint256 incentiveAmount) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        if (block.timestamp > auction.endTime) revert AuctionEnded(block.timestamp, auction.endTime);
        if (bidAmount <= auction.highestBid) revert BidTooLow(bidAmount, auction.highestBid);
        if (incentiveAmount > maxIncentive * bidAmount / 100)
            revert IncentiveTooHigh(incentiveAmount, maxIncentive);

        IERC20 bidToken = IERC20(auction.bidTokenAddress);
        bidToken.transferFrom(msg.sender, address(this), bidAmount);

        // Check for extra time condition
        if (block.timestamp > auction.endTime - extraTime) {
            auction.endTime += extraTime;
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

    /// @inheritdoc finalizeAuction
    function finalizeAuction(uint256 auctionId) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];
        if (block.timestamp < auction.endTime) revert AuctionNotEnded(block.timestamp, auction.endTime);

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
                IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(
                    address(this),
                    auction.highestBidder,
                    auction.tokens[i].tokenId
                );
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

    /// @inheritdoc withdrawPending
    function withdrawPending() external {
        uint256 amount = pendingWithdrawals[msg.sender].amount;
        address tokenAddress = pendingWithdrawals[msg.sender].tokenAddress;
        if (amount == 0) revert NoFeesRemaining();
        if (tokenAddress == address(0)) revert FeeTokenNotConfigured();

        pendingWithdrawals[msg.sender].amount = 0;
        pendingWithdrawals[msg.sender].tokenAddress = address(0);

        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    /// @inheritdoc cancelSpecificAuction
    function cancelSpecificAuction(uint256 auctionId) external restricted {
        if (auctionId >= nextAuctionId) revert InvalidAuction(auctionId);
        Auction storage auction = auctions[auctionId];

        if (auction.highestBidder != address(0)) {
            IERC20(auction.bidTokenAddress).transfer(
                auction.highestBidder,
                auction.highestBid - auction.totalIncentives
            );
        }

        for (uint i = 0; i < auction.tokens.length; i++) {
            IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(
                address(this),
                auction.seller,
                auction.tokens[i].tokenId
            );
        }

        auction.status = AuctionStatus.Cancelled;

        emit AuctionCancelled(auctionId);
    }

    /// @inheritdoc _pause
    function pause() external restricted {
        _pause();
    }

    /// @inheritdoc _unpause
    function unpause() external restricted {
        _unpause();
    }

    /// @inheritdoc setMinAuctionDuration
    function setMinAuctionDuration(uint32 _duration) external restricted {
        if (_duration < 1 minutes) revert InvalidAuctionDuration(_duration, 1 minutes, maxAuctionDuration);
        minAuctionDuration = _duration;
        emit MinAuctionDurationUpdated(_duration);
    }

    /// @inheritdoc setMaxAuctionDuration
    function setMaxAuctionDuration(uint32 _duration) external restricted {
        if (_duration > 52 weeks) revert InvalidAuctionDuration(_duration, minAuctionDuration, 52 weeks);
        maxAuctionDuration = _duration;
        emit MaxAuctionDurationUpdated(_duration);
    }

    /// @inheritdoc setMaxAssets
    function setMaxAssets(uint16 _assets) external restricted {
        if (_assets > 100) revert InvalidAAssetCount(_assets, 100);
        maxAssets = _assets;
        emit MaxAssetsUpdated(_assets);
    }

    /// @inheritdoc setMaxIncentive
    function setMaxIncentive(uint16 _incentive) external restricted {
        if (_incentive >= 100) revert IncentiveTooHigh(_assets, 99);
        maxIncentive = _incentive;
        emit MaxIncentiveUpdated(_incentive);
    }

    /// @inheritdoc setWarmUpTime
    function setWarmUpTime(uint32 _warmUp) external restricted {
        warmUpTime = _warmUp;
        emit WarmUpTimeUpdated(_warmUp);
    }

    /// @inheritdoc setExtraTime
    function setExtraTime(uint32 _extraTime) external restricted {
        if (_extraTime > 12 hours) revert InvalidExtraTime(_extraTime, 12 hours);
        extraTime = _extraTime;
        emit ExtraTimeUpdated(_extraTime);
    }

    /// @inheritdoc setMaxPayment
    function setMaxPayment(uint16 _maxPmt) external restricted {
        require(_maxPmt <= 1000, "Fees must be below 10%");
        maxPayment = _maxPmt;
        emit MaxPaymentUpdated(_maxPmt);
    }

    /// @inheritdoc getAuctionStatus
    function getAuctionStatus(uint256 auctionId) external view returns (AuctionStatus) {
        return auctions[auctionId].status;
    }

    /// @inheritdoc getAuctionEndTime
    function getAuctionEndTime(uint256 auctionId) external view returns (uint32) {
        return auctions[auctionId].endTime;
    }

    /// @inheritdoc cancelAuction
    function cancelAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];
        if (msg.sender != auction.seller) revert NotAuctionSeller(auction.seller, msg.sender);
        if (auction.status == AuctionStatus.Cancelled || auction.status == AuctionStatus.Closed)
            revert AuctionEnded(block.timestamp, auction.endTime);
        if (auction.status != AuctionStatus.Open) revert AuctionHasBids();

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

    /// @inheritdoc safeTransfer
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        try token.transfer(to, amount) {
            // Transfer successful
        } catch {
            // If transfer fails, add to pending withdrawals
            pendingWithdrawals[to].amount += amount;
            pendingWithdrawals[to].tokenAddress = address(token);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal restricted override {}
}
