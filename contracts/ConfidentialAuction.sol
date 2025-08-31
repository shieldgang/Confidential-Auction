// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {FHE, euint64, eaddress, ebool} from "@fhevm/solidity/lib/FHE.sol";
import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
contract ConfidentialAuction is ERC721Holder, ReentrancyGuard, SepoliaConfig {
    
    struct Auction {
        address seller;
        IERC721 nftContract;
        uint256 tokenId;
        euint64 encryptedHighestBid;
        eaddress encryptedHighestBidder;
        uint256 endTime;
        bool ended;
        euint64 encryptedReservePrice;
        mapping(address => euint64) encryptedBids;
        mapping(address => uint256) bidAmounts;
        mapping(address => bool) hasBid;
        mapping(address => bool) hasRefunded;
        address[] bidders;
        address winner;
        uint256 winningBid;
        bool sellerPaid;
        bool winnerRevealed;
    }
    
    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCounter;
    
    event AuctionCreated(uint256 indexed auctionId, address indexed seller, address nftContract, uint256 tokenId, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder);
    event AuctionEnded(uint256 indexed auctionId, address winner);
    
    
    function createAuction(
        address _nftContract,
        uint256 _tokenId,
        uint256 _duration,
        uint64 _reservePrice
    ) external returns (uint256) {
        require(_duration > 0, "Invalid duration");
        require(_nftContract != address(0), "Invalid NFT contract");
        
        IERC721(_nftContract).safeTransferFrom(msg.sender, address(this), _tokenId);
        
        uint256 auctionId = auctionCounter++;
        Auction storage auction = auctions[auctionId];
        
        auction.seller = msg.sender;
        auction.nftContract = IERC721(_nftContract);
        auction.tokenId = _tokenId;
        auction.endTime = block.timestamp + _duration;
        auction.ended = false;
        auction.winnerRevealed = false;
        
        auction.encryptedReservePrice = FHE.asEuint64(_reservePrice);
        auction.encryptedHighestBid = FHE.asEuint64(0);
        auction.encryptedHighestBidder = FHE.asEaddress(address(0));
        
        FHE.allowThis(auction.encryptedReservePrice);
        FHE.allowThis(auction.encryptedHighestBid);
        FHE.allowThis(auction.encryptedHighestBidder);
        
        emit AuctionCreated(auctionId, msg.sender, _nftContract, _tokenId, auction.endTime);
        return auctionId;
    }
    
    function placeBid(uint256 _auctionId, bytes32 _encryptedBid, bytes calldata _inputProof) external payable nonReentrant {
        Auction storage auction = auctions[_auctionId];
        require(block.timestamp < auction.endTime, "Auction ended");
        require(!auction.ended, "Auction finalized");
        require(msg.sender != auction.seller, "Seller cannot bid");
        require(msg.value > 0, "Bid must be greater than 0");
        
        // Handle previous bid refund
        if (auction.hasBid[msg.sender]) {
            uint256 previousBid = auction.bidAmounts[msg.sender];
            if (previousBid > 0) {
                payable(msg.sender).transfer(previousBid);
            }
        } else {
            auction.bidders.push(msg.sender);
            auction.hasBid[msg.sender] = true;
        }
        
        auction.bidAmounts[msg.sender] = msg.value;
        
        euint64 encryptedBidValue = FHE.asEuint64(uint64(uint256(_encryptedBid) % (2**64)));
        auction.encryptedBids[msg.sender] = encryptedBidValue;
        
        FHE.allowThis(encryptedBidValue);
        FHE.allow(encryptedBidValue, msg.sender);
        
        ebool isGreater = FHE.gt(encryptedBidValue, auction.encryptedHighestBid);
        auction.encryptedHighestBid = FHE.select(isGreater, encryptedBidValue, auction.encryptedHighestBid);
        auction.encryptedHighestBidder = FHE.select(isGreater, FHE.asEaddress(msg.sender), auction.encryptedHighestBidder);
        
        FHE.allowThis(auction.encryptedHighestBid);
        FHE.allow(auction.encryptedHighestBid, auction.seller);
        FHE.allowThis(auction.encryptedHighestBidder);
        FHE.allow(auction.encryptedHighestBidder, auction.seller);
        
        emit BidPlaced(_auctionId, msg.sender);
    }
    
    function endAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        require(block.timestamp >= auction.endTime, "Auction not ended");
        require(!auction.ended, "Already finalized");
        require(msg.sender == auction.seller, "Only seller can end");
        
        auction.ended = true;
        emit AuctionEnded(_auctionId, address(0)); // Winner revealed separately
    }
    
    function revealWinner(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        require(auction.ended, "Auction not ended");
        require(msg.sender == auction.seller, "Only seller can reveal");
        require(!auction.winnerRevealed, "Winner already revealed");
        require(auction.bidders.length > 0, "No bids placed");
        
        address actualWinner = auction.bidders[0];
        uint256 highestBidAmount = auction.bidAmounts[actualWinner];
        
        for (uint256 i = 1; i < auction.bidders.length; i++) {
            address bidder = auction.bidders[i];
            uint256 bidAmount = auction.bidAmounts[bidder];
            if (bidAmount > highestBidAmount) {
                highestBidAmount = bidAmount;
                actualWinner = bidder;
            }
        }
        
        auction.winner = actualWinner;
        auction.winningBid = highestBidAmount;
        auction.winnerRevealed = true;
        
        emit AuctionEnded(_auctionId, auction.winner);
    }
    
    function _decryptAddress(eaddress encrypted) internal pure returns (address) {
        return address(uint160(uint256(eaddress.unwrap(encrypted))));
    }
    
    function _decryptValue(euint64 encrypted) internal pure returns (uint256) {
        return uint256(euint64.unwrap(encrypted));
    }
    
    function getEncryptedBid(uint256 _auctionId, address _bidder) external view returns (euint64) {
        require(msg.sender == _bidder || msg.sender == auctions[_auctionId].seller, "Not authorized");
        return auctions[_auctionId].encryptedBids[_bidder];
    }
    
    function getEncryptedHighestBid(uint256 _auctionId) 
        external 
        view 
        returns (euint64) 
    {
        require(msg.sender == auctions[_auctionId].seller, "Only seller can view");
        return auctions[_auctionId].encryptedHighestBid;
    }
    
    // Standard auction claim functions
    function claimNFT(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        require(auction.ended, "Auction not ended");
        require(auction.winnerRevealed, "Winner not revealed yet");
        require(msg.sender == auction.winner, "Only winner can claim NFT");
        require(auction.nftContract.ownerOf(auction.tokenId) == address(this), "NFT already claimed");
        
        auction.nftContract.safeTransferFrom(address(this), auction.winner, auction.tokenId);
    }
    
    function claimRefund(uint256 _auctionId) external nonReentrant {
        Auction storage auction = auctions[_auctionId];
        require(auction.ended, "Auction not ended");
        require(auction.winnerRevealed, "Winner not revealed yet");
        require(msg.sender != auction.winner, "Winner cannot claim refund");
        require(auction.hasBid[msg.sender], "No bid to refund");
        require(!auction.hasRefunded[msg.sender], "Already refunded");
        
        uint256 refundAmount = auction.bidAmounts[msg.sender];
        require(refundAmount > 0, "No refund available");
        
        auction.hasRefunded[msg.sender] = true;
        payable(msg.sender).transfer(refundAmount);
    }
    
    function claimSellerPayment(uint256 _auctionId) external nonReentrant {
        Auction storage auction = auctions[_auctionId];
        require(auction.ended, "Auction not ended");
        require(auction.winnerRevealed, "Winner not revealed yet");
        require(msg.sender == auction.seller, "Only seller can claim payment");
        require(!auction.sellerPaid, "Already paid");
        require(auction.winningBid > 0, "No winning bid");
        
        auction.sellerPaid = true;
        payable(auction.seller).transfer(auction.winningBid);
    }
    
    function getAuctionInfo(uint256 _auctionId) 
        external 
        view 
        returns (
            address seller,
            address nftContract,
            uint256 tokenId,
            uint256 endTime,
            bool ended,
            uint256 bidderCount,
            address winner,
            uint256 winningBid
        ) 
    {
        Auction storage auction = auctions[_auctionId];
        return (
            auction.seller,
            address(auction.nftContract),
            auction.tokenId,
            auction.endTime,
            auction.ended,
            auction.bidders.length,
            auction.winner,
            auction.winningBid
        );
    }
    
    function getBidders(uint256 _auctionId) external view returns (address[] memory) {
        return auctions[_auctionId].bidders;
    }
    
    function hasUserBid(uint256 _auctionId, address _user) external view returns (bool) {
        return auctions[_auctionId].hasBid[_user];
    }
    
    function getUserBidAmount(uint256 _auctionId, address _user) external view returns (uint256) {
        return auctions[_auctionId].bidAmounts[_user];
    }
    
    function hasUserRefunded(uint256 _auctionId, address _user) external view returns (bool) {
        return auctions[_auctionId].hasRefunded[_user];
    }
    
    function hasSellerPaid(uint256 _auctionId) external view returns (bool) {
        return auctions[_auctionId].sellerPaid;
    }
}