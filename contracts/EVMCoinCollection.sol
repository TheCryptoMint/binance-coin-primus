// SPDX-License-Identifier: MIT

// EVMCoinCollection.sol
// Copyright (c) 2021 The Crypto Mint <https://cryptomint.one>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./BaseERC721.sol";

/**
 * @notice Crypto Mint EVM Coin Collection Contract
 */
contract EVMCoinCollection is BaseERC721, ReentrancyGuard {
  /**
  * @notice contract can receive Ether.
  */
  receive() external payable {}

  event Fund(address from, uint256 amount, uint256 tokenId);
  event Defund(address to, uint256 amount, uint256 tokenId);
  event OnMarket(uint256 tokenId, uint256 price);
  event OffMarket(uint256 tokenId);
  event Purchase(address seller, address buyer, uint256 tokenId, uint256 amount);
  event Melt(address owner, uint256 tokenId);

  uint256 public faceValue;

  string constant TOKEN_MUST_BE_FUNDED = "Token must be funded";
  string constant TOKEN_ID_DOES_NOT_EXIST = "Token id does not exist";
  string constant SENDER_MUST_BE_TOKEN_OWNER = "Sender must be token owner";
  string constant PRICE_MUST_BE_AT_LEAST_FACE_VALUE = "Price must be >= face value";
  string constant TOKEN_MUST_NOT_BE_FOR_SALE = "Token must not be for sale";
  string constant TOKEN_MUST_BE_FOR_SALE = "Token must be for sale";
  string constant BUYER_CANNOT_BE_OWNER = "Buyer cannot be owner";
  string constant VALUE_MUST_EQUAL_PRICE = "Value must equal price";
  string constant TOKEN_MUST_BE_UNFUNDED = "Token must be unfunded";
  string constant SENT_VALUE_MUST_BE_FACE_VALUE = "Sent value must = face value";

  mapping(uint256 => uint256) private _listPrices;
  mapping(uint256 => uint256) private _fundedValues;

  /**
  * @dev Initializes the contract with a mint limit
  * @param mintLimit the maximum number of eNFTs that can be minted
  * @param _faceValue the face value of the eNFT, the backing in Eth
  * @param name the collection name
  * @param symbol the collection symbol
  * @param baseURI the NFT base uri
  * @param contractURI the ERC721 contract metadata uri
  */
  constructor(
    uint256 mintLimit,
    uint256 _faceValue,
    string memory name,
    string memory symbol,
    string memory baseURI,
    string memory contractURI
  ) BaseERC721(
    name,
    symbol,
    mintLimit,
    baseURI,
    contractURI
  ) payable {
    faceValue = _faceValue;
  }

  /**
   * @dev Mints a new eNFT in the collection
   *
   * See {ERC721-_mint}.
   *
   * Requirements:
   * - the caller must have the `MINTER_ROLE`.
   * - the total supply must be less than the collection mint limit
   */
  function mint() onlyMinter public returns (uint256) {
    uint256 tokenId = BaseERC721._mint();
    return tokenId;
  }

  /**
   * @dev Returns the contract balance in Eth
   */
  function getBalance() public view returns (uint) {
    return address(this).balance;
  }

  /**
   * @dev Funds the eNFT
   * @param tokenId the token id to fund
   *
   * Requirements:
   * - the caller must have the `MINTER_ROLE`.
   * - the token must exist
   * - the token must be unfunded
   * - the payable amount must equal the collection face value
   */
  function fund(uint256 tokenId) nonReentrant onlyMinter whenNotPaused external payable {
    // Confirm token exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Ensure the coin is unfunded
    require(_fundedValues[tokenId] == uint256(0), TOKEN_MUST_BE_UNFUNDED);
    // Ensure the amount is exactly equal to the face faceValue
    require(msg.value == faceValue, SENT_VALUE_MUST_BE_FACE_VALUE);
    // SENT_VALUE_MUST_BE_FACE_VALUE
    _fundedValues[tokenId] = msg.value;
    // Emit a Deposit event
    emit Fund(msg.sender, msg.value, tokenId);
  }

  /**
   * @dev Defunds the eNFT
   * @param tokenId the token id to defund
   *
   * Requirements:
   * - the caller must have the `MINTER_ROLE`.
   * - the caller must be the token owner
   * - the token must exist
   * - the token must be funded
   */
  function defund(uint256 tokenId) nonReentrant onlyMinter whenNotPaused external {
    // Confirm token exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // confirm the token is fully funded
    require(_fundedValues[tokenId] == faceValue, TOKEN_MUST_BE_FUNDED);
    // Minter may defund only when the coin owner
    require(msg.sender == ownerOf(tokenId), SENDER_MUST_BE_TOKEN_OWNER);
    // withdraw funds to minter
    _withdrawFunds(tokenId);
  }

  /**
   * @dev Burns the eNFT
   * @param tokenId the token id to melt
   *
   * Requirements:
   * - the caller must be the token owner
   * - the token must exist
   * - the token must be funded
   * - the token must not be listed for sale
   */
  function burn(uint256 tokenId) nonReentrant whenNotPaused external {
    // Ensure the coin exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Only the token owner may burn
    require(_isOwner(tokenId), SENDER_MUST_BE_TOKEN_OWNER);
    // Token must be funded
    require(_fundedValues[tokenId] == faceValue, TOKEN_MUST_BE_FUNDED);
    // Token may not be for sale
    require(_listPrices[tokenId] == uint256(0), TOKEN_MUST_NOT_BE_FOR_SALE);
    // withdraw funds to owner
    _withdrawFunds(tokenId);
    ERC721._burn(tokenId);
    // emits Transfer event
    emit Melt(msg.sender, tokenId);
  }

  /**
   * @dev Lists the eNFT for sale on the Crypto Mint storefront
   * @param tokenId the token id to list
   * @param price the price at which to list
   *
   * Requirements:
   * - the caller must be the token owner
   * - the token must exist
   * - the token must be funded
   * - the list price must be >= the face value
   */
  function allowBuy(uint256 tokenId, uint256 price) external {
    // Make sure the coin exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Only the token owner may invoke
    require(_isOwner(tokenId), SENDER_MUST_BE_TOKEN_OWNER);
    // Listing price must be at least as much as the face value
    require(price >= faceValue, PRICE_MUST_BE_AT_LEAST_FACE_VALUE);
    // Token must be funded
    require(_fundedValues[tokenId] == faceValue, TOKEN_MUST_BE_FUNDED);
    _listPrices[tokenId] = price;

    emit OnMarket(tokenId, price);
  }

  /**
   * @dev deLists the eNFT for sale on the Crypto Mint storefront
   * @param tokenId the token id to delist
   *
   * Requirements:
   * - the caller must be the token owner
   * - the token must exist
   * - the token must be funded
   * - the list price must be >= the face value
   */
  function disallowBuy(uint256 tokenId) external {
    // Ensure the coin exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Only the token owner may invoke
    require(_isOwner(tokenId), SENDER_MUST_BE_TOKEN_OWNER);
    // Token must be funded
    require(_fundedValues[tokenId] == faceValue, TOKEN_MUST_BE_FUNDED);
    // Delist the coin if listed
    _disallowBuy(tokenId);
  }

  /**
   * @dev purchase the eNFT from the Crypto Mint storefront
   * @param tokenId the token id to purchase
   *
   * Requirements:
   * - the token must exist
   * - the token must be funded
   * - the caller cannot be the owner
   * - the token must have a price (be listed for sale)
   * - there must be sufficient Eth in the tx to meet the price
   */
  function buy(uint256 tokenId) nonReentrant external payable {
    // Ensure the coin exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Capture the seller
    address seller = ownerOf(tokenId);
    // Require that the buyer is not the seller
    require(seller != msg.sender, BUYER_CANNOT_BE_OWNER);
    // Require that the coins is on sale
    require(_listPrices[tokenId] >= faceValue, PRICE_MUST_BE_AT_LEAST_FACE_VALUE);
    // Require that there is enough Ether in the transaction
    require(msg.value == _listPrices[tokenId], VALUE_MUST_EQUAL_PRICE);

    BaseERC721._buy(tokenId);

    safeTransferFrom(seller, msg.sender, tokenId);
    // Transfer the payment to the seller
    payable(seller).transfer(msg.value);

    // Reset the price to zero (not for sale)
    _listPrices[tokenId] = uint256(0);
    emit Purchase(seller, msg.sender, tokenId, msg.value);
  }

  /**
   * @notice Returns all the relevant information about a specific eNFT.
   * @param tokenId the token id to query
   * @return pertinent eNFT attributes
   */
  function getCoin(uint256 tokenId) external view
  returns (
    bool forSale,
    uint256 price,
    uint256 fundedValue,
    string memory uri,
    address owner
  ) {
    price = _listPrices[tokenId];
    forSale = price != uint256(0);
    fundedValue = _fundedValues[tokenId];

    if (_exists(tokenId)) {
      owner = ownerOf(tokenId);
      uri = tokenURI(tokenId);
    }
    else {
      owner = address(0);
      uri = '';
    }
  }

  /**
   * @dev If the eNFT is listed for sale (has a price)
   *      delist it (reset the price to zero) prior to transfer
   * @param tokenId the token id to query
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(BaseERC721) {
    if (_exists(tokenId)) {
      _disallowBuy(tokenId);
    }

    super._beforeTokenTransfer(from, to, tokenId);
  }

  /**
   * @dev sets the list price of the token to nil
   * @param tokenId the token id to query
   */
  function _disallowBuy(uint256 tokenId) internal {
    if (_listPrices[tokenId] != uint256(0)) {
      _listPrices[tokenId] = uint256(0);

      emit OffMarket(tokenId);
    }
  }

  /**
   * @dev withdraw the funded value for a tokenId to the caller's wallet
   * @param tokenId the token id being defunded
   */
  function _withdrawFunds(uint256 tokenId) private {
    // transfer the balance to the caller
    payable(address(uint160(msg.sender))).transfer(_fundedValues[tokenId]);
    // Emit a Withdraw event
    emit Defund(msg.sender, _fundedValues[tokenId], tokenId);
    // Set the coin's funded value to nil
    _fundedValues[tokenId] = uint256(0);
  }
}
