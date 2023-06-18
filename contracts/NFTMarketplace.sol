// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

error NftMarketplace_PriceMustBeAboveZero();

contract NftMarketplace is ReentrancyGuard {
  // Struct of the NFT price and seller
  struct Listing {
    uint256 price;
    address seller;
  }

  // Mapping of NFT Address to NFT Token ID to Listing seller and price 
  mapping (address => mapping(uint256 => Listing)) private s_listings;
  // Mapping of proceeds that an owner has
  mapping (address => uint256) private s_proceeds;

  event ItemListed(
    address indexed seller,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
  );

  event ItemCanceled(
    address indexed seller,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
  );

  event ItemBought(
    address indexed buyer,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
  );

  modifier isListed(address nftAddress, uint256 tokenId, bool shouldBeListed) {
    Listing memory listedItem = s_listings[nftAddress][tokenId];
    if (listedItem.price > 0 && shouldBeListed == false) {
      // Error
    } else if (listedItem.price <= 0 && shouldBeListed == true) {
      // Error
    }
    _;
  }

  modifier isOwner(address nftAddress, uint256 tokenId, address spender, bool shouldBeOwner) {
    IERC721 nft = IERC721(nftAddress);
    address owner = nft.ownerOf(tokenId);
    if (owner != spender && shouldBeOwner == true) {
      // Error
    } else if (owner == spender && shouldBeOwner == false) {
      // Error
    }
    _;
  }

  function listItem(address nftAddress, uint256 tokenId, uint256 price) external isListed(nftAddress, tokenId, false) isOwner(nftAddress, tokenId, msg.sender, true) {
    if (price <= 0) {
      revert NftMarketplace_PriceMustBeAboveZero();
    }
    IERC721 nft = IERC721(nftAddress);
    if (nft.getApproved(tokenId) != address(this)) {
      // error
    }

    s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
    emit ItemListed(msg.sender, nftAddress, tokenId, price);
  }

  function cancelListing(address nftAddress, uint256 tokenId, uint256 price) external isListed(nftAddress, tokenId, true) isOwner(nftAddress, tokenId, msg.sender, true) {
    delete s_listings[nftAddress][tokenId];
    emit ItemCanceled(msg.sender, nftAddress, tokenId, price);
  }

  function buyItem(address nftAddress, uint256 tokenId) external payable isListed(nftAddress, tokenId, true) isOwner(nftAddress, tokenId, msg.sender, false) {
    Listing memory listedItem = s_listings[nftAddress][tokenId];
    if (msg.value < listedItem.price) {
      // Error
    }
    s_proceeds[listedItem.seller] += msg.value;
    delete s_listings[nftAddress][tokenId];
    IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
    emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
  }

  function updateListing(address nftAddress, uint256 tokenId, uint256 newPrice) external nonReentrant isListed(nftAddress, tokenId, true) isOwner(nftAddress, tokenId, msg.sender, true) {
    if (newPrice <= 0) {
      revert NftMarketplace_PriceMustBeAboveZero();
    }
    s_listings[nftAddress][tokenId].price = newPrice;
    emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
  }

  function withdrawProceeds() external {
    uint256 proceeds = s_proceeds[msg.sender];
    if (proceeds <= 0) {
      revert NftMarketplace_PriceMustBeAboveZero();
    }
    s_proceeds[msg.sender] = 0;
    (bool success,) = payable(msg.sender).call{value: proceeds}('');
    require(success, "Transfer failed!");
  }

  function getListing(address nftAddress, uint256 tokenId) external view returns(Listing memory) {
    return s_listings[nftAddress][tokenId];
  }

  function getProceeds(address seller) external view returns(uint256) {
    return s_proceeds[seller];
  }
}