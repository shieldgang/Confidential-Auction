// contracts/MockNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MockNFT is ERC721, Ownable {
    using Strings for uint256;
    
    uint256 private _tokenIdCounter;
    string private _baseTokenURI;
    
    constructor() ERC721("Mock NFT Collection", "MNFT") Ownable(msg.sender) {
        _baseTokenURI = "https://api.example.com/metadata/";
    }
    
    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }
    
    function publicMint(address to) public returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }
    
    function tokenURI(uint256 tokenId) 
        public 
        view 
        override 
        returns (string memory) 
    {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return string(abi.encodePacked(_baseTokenURI, tokenId.toString(), ".json"));
    }
}