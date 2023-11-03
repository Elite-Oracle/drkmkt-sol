# Solidity API

## DarkMarketAuctionStorage

_Contract module which allows children to implement an emergency stop
mechanism that can be triggered by an authorized account.

This module is used through inheritance. It will make available the
modifiers `whenNotPaused` and `whenPaused`, which can be applied to
the functions of your contract. Note that they will not be pausable by
simply including this module, only once the modifiers are put in place._

### DMAStorage

```solidity
struct DMAStorage {
  uint256 _nextAuctionId;
  uint256 _minAuctionDuration;
  uint256 _maxAuctionDuration;
  uint256 _warmUpTime;
  uint256 _maxIncentive;
  uint256 _maxPayment;
  uint256 _maxAssets;
  uint256 _extraTime;
  mapping(uint256 => struct IDarkMarketAuctionStructures.Auction) _auctions;
}
```

### __DMAStorage_init

```solidity
function __DMAStorage_init() internal
```

_Initializes the contract storage._

### getAuction

```solidity
function getAuction(uint256 auctionId_) public view returns (struct IDarkMarketAuctionStructures.Auction)
```

Custom 'getter' function to return the Token Details for a given auction

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| auctionId_ | uint256 | The ID of the auction to get token details for |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct IDarkMarketAuctionStructures.Auction | The details of the token at the given index |

### nextAuctionId

```solidity
function nextAuctionId() public view returns (uint256)
```

### minAuctionDuration

```solidity
function minAuctionDuration() public view returns (uint256)
```

### maxAuctionDuration

```solidity
function maxAuctionDuration() public view returns (uint256)
```

### warmUpTime

```solidity
function warmUpTime() public view returns (uint256)
```

### maxIncentive

```solidity
function maxIncentive() public view returns (uint256)
```

### maxPayment

```solidity
function maxPayment() public view returns (uint256)
```

### maxAssets

```solidity
function maxAssets() public view returns (uint256)
```

### extraTime

```solidity
function extraTime() public view returns (uint256)
```

### _setNextAuctionId

```solidity
function _setNextAuctionId(uint256 nextAuctionId_) internal
```

### _setMinAuctionDuration

```solidity
function _setMinAuctionDuration(uint256 minAuctionDuration_) internal
```

### _setMaxAuctionDuration

```solidity
function _setMaxAuctionDuration(uint256 maxAuctionDuration_) internal
```

### _setWarmUpTime

```solidity
function _setWarmUpTime(uint256 warmUpTime_) internal
```

### _setMaxIncentive

```solidity
function _setMaxIncentive(uint256 maxIncentive_) internal
```

### _setMaxPayment

```solidity
function _setMaxPayment(uint256 maxPayment_) internal
```

### _setMaxAssets

```solidity
function _setMaxAssets(uint256 maxAssets_) internal
```

### _setExtraTime

```solidity
function _setExtraTime(uint256 extraTime_) internal
```

### _getNextAuctionId

```solidity
function _getNextAuctionId() internal returns (uint256)
```

### _getAuction

```solidity
function _getAuction(uint256 auctionId_) internal view returns (struct IDarkMarketAuctionStructures.Auction)
```

## DarkMarketAuction

This contract allows users to start, bid, and finalize auctions for a variety of ERC tokens (digital assets)

### constructor

```solidity
constructor() public
```

### initialize

```solidity
function initialize() public
```

### startAuction

```solidity
function startAuction(uint256 startPrice, uint256 duration, struct IDarkMarketAuctionStructures.TokenDetail[] _tokens, address ERC20forBidding, struct IDarkMarketAuctionStructures.FeeDetail _fees) external
```

Starts an auction by transferring the ERC721 tokens into the contract.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| startPrice | uint256 | The starting price for the auction. |
| duration | uint256 | The duration of the auction in seconds (86,400 = 1 day). |
| _tokens | struct IDarkMarketAuctionStructures.TokenDetail[] | The array of TokenDetail containing the ERC721 contract addresses and token IDs. |
| ERC20forBidding | address | The address of the ERC20 token used for bidding. |
| _fees | struct IDarkMarketAuctionStructures.FeeDetail | The fees and address for royalties. |

### bid

```solidity
function bid(uint256 auctionId, uint256 bidAmount, uint256 incentiveAmount) external
```

Allows users to place bids on an auction.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| auctionId | uint256 | The ID of the auction. |
| bidAmount | uint256 | The bid amount. |
| incentiveAmount | uint256 | The bidder incentive. |

### finalizeAuction

```solidity
function finalizeAuction(uint256 auctionId) external
```

_Finalizes an auction, handling transfers to the seller, highest bidder, and owner. Depending on the caller,
     different transfers are executed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| auctionId | uint256 | The ID of the auction to finalize. |

### cancelSpecificAuction

```solidity
function cancelSpecificAuction(uint256 auctionId) external
```

_Failsafe function to cancel a specific auction by the contract owner._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| auctionId | uint256 | The ID of the auction. |

### setMinAuctionDuration

```solidity
function setMinAuctionDuration(uint256 _duration) external
```

_Allows the contract owner to set the minimum auction duration._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _duration | uint256 | The new minimum auction duration. |

### setMaxAuctionDuration

```solidity
function setMaxAuctionDuration(uint256 _duration) external
```

_Allows the contract owner to set the maximum auction duration._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _duration | uint256 | The new maximum auction duration. |

### setMaxAssets

```solidity
function setMaxAssets(uint16 _assets) external
```

_Allows the contract owner to set the maximum number of assets allowed in each auction._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _assets | uint16 | The new minimum auction duration. |

### setMaxIncentive

```solidity
function setMaxIncentive(uint16 _incentive) external
```

_Allows the contract owner to set the maximum incentive._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _incentive | uint16 | The new maximum incentive in percentage. |

### setWarmUpTime

```solidity
function setWarmUpTime(uint256 _warmUp) external
```

_Allows the contract owner to set the warm-up time._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _warmUp | uint256 | The new warm-up time. |

### setExtraTime

```solidity
function setExtraTime(uint256 _extTime) external
```

_Allows the contract owner to set the extra time added when a bidder places a bid in the final minutes of an
     auction. Only allowed to be 12 hours maximum._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _extTime | uint256 |  |

### setMaxPayment

```solidity
function setMaxPayment(uint256 _maxPmt) external
```

_Allows the contract owner to set the maximum payment for contract fees and royalties. 10% is the maximum
     and the scale is 10^3 (1000 = 10%)._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _maxPmt | uint256 | The new warm-up time. |

### cancelAuction

```solidity
function cancelAuction(uint256 auctionId) public
```

_Allows the Seller to cancel the auction if no bids have been placed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| auctionId | uint256 | The ID of the auction. |

### safeTransfer

```solidity
function safeTransfer(contract IERC20 token, address to, uint256 amount) internal
```

### pause

```solidity
function pause() external
```

### unpause

```solidity
function unpause() external
```

### _authorizeUpgrade

```solidity
function _authorizeUpgrade(address newImplementation) internal
```

_Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
{upgradeToAndCall}.

Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.

```solidity
function _authorizeUpgrade(address) internal onlyOwner {}
```_

## IDarkMarketAuction

Interface to interact with the DarkMarketAuction contract.

### AuctionStarted

```solidity
event AuctionStarted(uint256 auctionId, address seller, uint256 startPrice, uint256 endTime)
```

Auction has started.

### BidPlaced

```solidity
event BidPlaced(uint256 auctionId, address bidder, uint256 amount, uint256 incentive, uint256 endTime)
```

Bid is placed.

### SellerFinalized

```solidity
event SellerFinalized(uint256 auctionId, address seller, uint256 amount)
```

Auction is finalized.

### BidderFinalized

```solidity
event BidderFinalized(uint256 auctionId, address winner, uint256 amount)
```

Auction is finalized.

### AuctionFinalized

```solidity
event AuctionFinalized(uint256 auctionId, uint256 fee, address royaltyAddress, uint256 royalty)
```

Auction is finalized.

### AuctionCancelled

```solidity
event AuctionCancelled(uint256 auctionId)
```

Auction is cancelled.

### IncentiveReceived

```solidity
event IncentiveReceived(address bidder, uint256 amount)
```

Incentive is received

### MinAuctionDurationUpdated

```solidity
event MinAuctionDurationUpdated(uint256 newDuration)
```

### MaxAuctionDurationUpdated

```solidity
event MaxAuctionDurationUpdated(uint256 newDuration)
```

### MaxIncentiveUpdated

```solidity
event MaxIncentiveUpdated(uint16 newIncentive)
```

### WarmUpTimeUpdated

```solidity
event WarmUpTimeUpdated(uint256 newWarmUp)
```

### MaxPaymentUpdated

```solidity
event MaxPaymentUpdated(uint256 newMaxPmt)
```

### ExtraTimeUpdated

```solidity
event ExtraTimeUpdated(uint256 newExtraTime)
```

### MaxAssetsUpdated

```solidity
event MaxAssetsUpdated(uint256 newMaxAssets)
```

### TransferFailed

```solidity
event TransferFailed(address tokenAddress, address to, uint256 tokenId)
```

### InvalidAAssetCount

```solidity
error InvalidAAssetCount(uint256 count, uint256 max)
```

Asset count is greater than the maximum allowed or zero

### InvalidAuctionDuration

```solidity
error InvalidAuctionDuration(uint256 duration, uint256 min, uint256 max)
```

Auction duration is less than the minimum or greater than the maximum

### InvalidAuctionFeePercentage

```solidity
error InvalidAuctionFeePercentage(uint256 fee, uint256 max)
```

Auction fee percentage is too high

### InvalidRoyaltyFeePercentage

```solidity
error InvalidRoyaltyFeePercentage(uint256 fee, uint256 max)
```

Royalty fee percentage is too high

### IncentiveTooHigh

```solidity
error IncentiveTooHigh(uint256 incentiveAmount, uint256 maxIncentive)
```

Incentive is too high

### InvalidAuction

```solidity
error InvalidAuction(uint256 auctionId)
```

Auction has not been created

### AuctionNotStarted

```solidity
error AuctionNotStarted(uint256 now, uint256 endTime)
```

Auction has been created but not started

### AuctionHasBids

```solidity
error AuctionHasBids()
```

Bids have been made on the auction it cannot be cancelled by the Seller

### AuctionNotEnded

```solidity
error AuctionNotEnded(uint256 now, uint256 endTime)
```

Auction has not ended it cannot be finalized

### AuctionEnded

```solidity
error AuctionEnded(uint256 now, uint256 endTime)
```

Auction has ended it cannot be cancelled by the Seller

### BidTooLow

```solidity
error BidTooLow(uint256 bidAmount, uint256 highestBid)
```

Bid is too low to outbid the current highest bid

### NotAuctionSeller

```solidity
error NotAuctionSeller(address seller, address msgSender)
```

Sender is not the seller

### NoFeesRemaining

```solidity
error NoFeesRemaining()
```

Current accrued fees are empty

### FeeTokenNotConfigured

```solidity
error FeeTokenNotConfigured()
```

Attempt to withdraw without fee token having been set

### InvalidExtraTime

```solidity
error InvalidExtraTime(uint256 extraTime, uint256 max)
```

Extra time is too long

### startAuction

```solidity
function startAuction(uint256 startPrice, uint256 duration, struct IDarkMarketAuctionStructures.TokenDetail[] _tokens, address ERC20forBidding, struct IDarkMarketAuctionStructures.FeeDetail _fees) external
```

Starts an auction by transferring the ERC721 tokens into the contract.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| startPrice | uint256 | The starting price for the auction. |
| duration | uint256 | The duration of the auction in seconds (86,400 = 1 day). |
| _tokens | struct IDarkMarketAuctionStructures.TokenDetail[] | The array of TokenDetail containing the ERC721 contract addresses and token IDs. |
| ERC20forBidding | address | The address of the ERC20 token used for bidding. |
| _fees | struct IDarkMarketAuctionStructures.FeeDetail | The fees and address for royalties. |

### bid

```solidity
function bid(uint256 auctionId, uint256 bidAmount, uint256 incentiveAmount) external
```

Allows users to place bids on an auction.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| auctionId | uint256 | The ID of the auction. |
| bidAmount | uint256 | The bid amount. |
| incentiveAmount | uint256 | The bidder incentive. |

### finalizeAuction

```solidity
function finalizeAuction(uint256 auctionId) external
```

_Finalizes an auction, handling transfers to the seller, highest bidder, and owner. Depending on the caller,
     different transfers are executed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| auctionId | uint256 | The ID of the auction to finalize. |

### cancelSpecificAuction

```solidity
function cancelSpecificAuction(uint256 auctionId) external
```

_Failsafe function to cancel a specific auction by the contract owner._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| auctionId | uint256 | The ID of the auction. |

### setMinAuctionDuration

```solidity
function setMinAuctionDuration(uint256 _duration) external
```

_Allows the contract owner to set the minimum auction duration._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _duration | uint256 | The new minimum auction duration. |

### setMaxAuctionDuration

```solidity
function setMaxAuctionDuration(uint256 _duration) external
```

_Allows the contract owner to set the maximum auction duration._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _duration | uint256 | The new maximum auction duration. |

### setMaxAssets

```solidity
function setMaxAssets(uint16 _assets) external
```

_Allows the contract owner to set the maximum number of assets allowed in each auction._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _assets | uint16 | The new minimum auction duration. |

### setMaxIncentive

```solidity
function setMaxIncentive(uint16 _incentive) external
```

_Allows the contract owner to set the maximum incentive._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _incentive | uint16 | The new maximum incentive in percentage. |

### setWarmUpTime

```solidity
function setWarmUpTime(uint256 _warmUp) external
```

_Allows the contract owner to set the warm-up time._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _warmUp | uint256 | The new warm-up time. |

### setExtraTime

```solidity
function setExtraTime(uint256 _extraTime) external
```

_Allows the contract owner to set the extra time added when a bidder places a bid in the final minutes of an
     auction. Only allowed to be 12 hours maximum._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _extraTime | uint256 | The new extra auction time. |

### setMaxPayment

```solidity
function setMaxPayment(uint256 _maxPmt) external
```

_Allows the contract owner to set the maximum payment for contract fees and royalties. 10% is the maximum
     and the scale is 10^3 (1000 = 10%)._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _maxPmt | uint256 | The new warm-up time. |

### cancelAuction

```solidity
function cancelAuction(uint256 auctionId) external
```

_Allows the Seller to cancel the auction if no bids have been placed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| auctionId | uint256 | The ID of the auction. |

## IDarkMarketAuctionStructures

Interface to hold the global data structures for the DarkMarketAuction contract.

### AuctionStatus

Represents the status of an auction

```solidity
enum AuctionStatus {
  Open,
  BidReceived,
  ExtraTime,
  Closed,
  Cancelled
}
```

### TokenType

Represents the Contract Address, Token ID, and additional details for every token (ERC721 or ERC1155)

```solidity
enum TokenType {
  ERC721,
  ERC1155
}
```

### TokenDetail

```solidity
struct TokenDetail {
  address tokenAddress;
  uint256 tokenId;
  uint256 tokenQuantity;
  enum IDarkMarketAuctionStructures.TokenType tokenType;
}
```

### FeeDetail

Represents the Contract Fees for every auction

```solidity
struct FeeDetail {
  uint256 contractFee;
  uint256 royaltyFee;
  address royaltyAddress;
}
```

### Auction

Represents an auction for ERC721 tokens

```solidity
struct Auction {
  address payable seller;
  address highestBidder;
  address bidTokenAddress;
  uint256 startTime;
  uint256 endTime;
  uint256 highestBid;
  uint256 bidderIncentive;
  uint256 totalIncentives;
  enum IDarkMarketAuctionStructures.AuctionStatus status;
  struct IDarkMarketAuctionStructures.FeeDetail fees;
  struct IDarkMarketAuctionStructures.TokenDetail[] tokens;
}
```

## AddressBook

### ChainNotConfigured

```solidity
error ChainNotConfigured(uint256 chainId)
```

### TreasuryNotConfigured

```solidity
error TreasuryNotConfigured(uint256 chainId)
```

### accessManager

```solidity
function accessManager() internal view returns (address)
```

### treasury

```solidity
function treasury() internal view returns (address)
```

## EliteOracleAccessManager

### constructor

```solidity
constructor() public
```

### initialize

```solidity
function initialize() public
```

### _authorizeUpgrade

```solidity
function _authorizeUpgrade(address newImplementation) internal
```

_Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
{upgradeToAndCall}.

Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.

```solidity
function _authorizeUpgrade(address) internal onlyOwner {}
```_

