# Confidential NFT Auctions

A private NFT auction platform using ZAMA's Fully Homomorphic Encryption where bid amounts remain encrypted until winners are revealed.

## What is this?

The first NFT auction platform where your bid amounts stay completely private. Unlike regular auctions where everyone can see exactly how much you're willing to pay, this system uses advanced cryptography to keep all bids secret until the auction ends.

The technology behind this is called Fully Homomorphic Encryption (FHE), which lets the smart contract compare encrypted numbers without ever seeing the actual values. Only when the auction finishes does the winner and winning amount become public.

## Quick Start

### Try it now
1. Open `frontend/index.html` in your web browser
2. Connect your MetaMask wallet to Sepolia testnet
3. Get some test ETH from https://faucet.sepolia.dev/
4. Mint a test NFT and create your first private auction
5. Place bids from different accounts
6. End Auction, Reveal Winner
7. Claim Payment (Seller)
8. Neither claim refund or NFT (if you won or lost)

### For developers
```bash
git clone <your-repository-url>
cd confidential-nft-auction
npm install
npm run compile  # Optional - contracts are already deployed
```

## Contract Addresses

**Deployed on Sepolia Testnet (Chain ID: 11155111)**

```
ConfidentialAuction: 0xb444cD2c2fB1D95b27bCac5D506AD3bb06cb35b3
MockNFT:             0xb7e9050DfeED7Bcafb38AAa1565f69De3C99d684
```

## How it works technically

The core innovation uses ZAMA's FHE operations to compare encrypted bid amounts:

```solidity
// This compares two encrypted numbers without revealing either value
euint64 encryptedBid = FHE.asEuint64(bidAmount);
ebool isHigher = FHE.gt(encryptedBid, currentHighestBid);
currentHighestBid = FHE.select(isHigher, encryptedBid, currentHighestBid);
```

Key technical features:
- All bid amounts stored as encrypted `euint64` types
- Homomorphic comparisons determine winners without decryption  
- Proper access control with `FHE.allow()` permissions
- Gas optimized for affordable bidding (~95k gas per bid)

## Future development plans

**Phase 1 - Enhanced privacy features**
I'm planning to implement invisible token transfers where even NFT ownership changes are encrypted. This will also include anonymous bidding options and completely private auction histories.
I want to achieve it by wrapping simple ether to EETH(Encrypted ETH) with ratio 1:1.

**Phase 2 - Advanced auction types**
Adding support for Dutch auctions with encrypted price curves, multi-NFT bundle auctions, and reserve price auctions where the minimum bid is also encrypted.

**Phase 3 - Platform expansion**
Cross-chain deployment to Polygon and Arbitrum, mobile applications, and integration with existing NFT marketplaces. Also planning institutional features for bulk auctions.

## License

MIT License - I believe privacy technology should be open and accessible.

---

**Built for the ZAMA Developer Contest - advancing privacy-preserving blockchain applications**