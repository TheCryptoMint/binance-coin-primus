// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Giftable.sol";

contract BNBPCollection is Giftable, ReentrancyGuard {
  /**
  * @notice contract can receive Ether.
  */
  receive() external payable {}

  event Deposit(address from, uint256 amount, uint256 tokenId);
  event Withdraw(address to, uint256 amount, uint256 tokenId);
  event OnMarket(uint256 tokenId, uint256 price);
  event OffMarket(uint256 tokenId);
  event Purchase(address seller, address buyer, uint256 tokenId, uint256 amount);

  uint256 public _faceValue;

//  string constant TOKEN_MUST_BE_FUNDED = "token must be funded";
//  string constant TOKEN_ID_DOES_NOT_EXIST = "tokenId does not exist";
//  string constant SENDER_MUST_BE_TOKEN_OWNER = 'token not owned';
//  string constant PRICE_MUST_BE_AT_LEAST_FACE_VALUE = "";
//  string constant TOKEN_MUST_NOT_BE_FOR_SALE = 'token must not be for sale';

  string constant TOKEN_MUST_BE_FUNDED = "";
  string constant TOKEN_ID_DOES_NOT_EXIST = "";
  string constant SENDER_MUST_BE_TOKEN_OWNER = "";
  string constant PRICE_MUST_BE_AT_LEAST_FACE_VALUE = "";
  string constant TOKEN_MUST_NOT_BE_FOR_SALE = "";
  string constant TOKEN_MUST_BE_FOR_SALE = "";
  string constant BUYER_CANNOT_BE_OWNER = "";
  string constant TOKEN_PRICE_MUST_BE_AT_LEAST_FACE_VALUE = ""; // "coin must have a price greater than face value"
  string constant MESSAGE_VALUE_MUST_EQUAL_PRICE = "";
//  string constant TOKEN_MUST_BE_UNFUNDED = "E10";
//  string constant SENT_VALUE_MUST_BE_FACE_VALUE = "E11";

  mapping(uint256 => uint256) private _listPrices;
  mapping(uint256 => uint256) private _fundedValues;

  /**
  * @dev Initializes the contract with a mint limit
  * @param mintLimit the maximum tokens a given address may own at a given time
  */
  constructor(
    uint256 mintLimit,
    uint256 __faceValue,
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
    _faceValue = __faceValue;
  }

  function faceValue() public view returns(uint256) {
    return _faceValue;
  }

  /**
   * @dev Creates `amount` new tokens for `to`.
   *
   * See {ERC20-_mint}.
   *
   * Requirements:
   * - the caller must have the `MINTER_ROLE`.
   * - the total supply must be less than the collection mint limit
   */
  function mint() onlyMinter public returns (uint256) {
    uint256 tokenId = BaseERC721._mint();
//    Coin memory _coin = createCoin(_tokenId);
//    coins[_tokenId] = _coin;

    return tokenId;
  }

  function getBalance() public view returns (uint) {
    return address(this).balance;
  }

  function fund(uint256 tokenId) nonReentrant onlyMinter whenNotPaused external payable {
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Ensure the coin is unfunded
    require(_fundedValues[tokenId] == uint256(0)); //, TOKEN_MUST_BE_UNFUNDED);
    // Ensure the amount is exactly equal to the face faceValue
    require(msg.value == _faceValue); // SENT_VALUE_MUST_BE_FACE_VALUE
    _fundedValues[tokenId] = msg.value;
    // Emit a Deposit event
    emit Deposit(msg.sender, msg.value, tokenId);
  }

  function defund(uint256 tokenId) nonReentrant onlyMinter whenNotPaused external {
    // Confirm token exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // confirm the token is fully funded
    require(_fundedValues[tokenId] == _faceValue);
    // Minter may defund only when the coin owner
    require(msg.sender == ownerOf(tokenId), SENDER_MUST_BE_TOKEN_OWNER);
    // withdraw funds to minter
    _withdraw(tokenId);
  }

  function burn(uint256 tokenId) nonReentrant whenNotPaused external {
    // Ensure the coin exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Only the token owner may burn
    require(_isOwner(tokenId), SENDER_MUST_BE_TOKEN_OWNER);
    // Token must be funded
    require(_fundedValues[tokenId] == _faceValue, TOKEN_MUST_BE_FUNDED);
    // Token may not be for sale
    require(_listPrices[tokenId] == uint256(0), TOKEN_MUST_NOT_BE_FOR_SALE);
    // withdraw funds to owner
    _withdraw(tokenId);
    ERC721._burn(tokenId); // emits Transfer event
  }

  // callable by owner only, after specified time
  function _withdraw(uint256 tokenId) private {
    // transfer the balance to the caller
    payable(address(uint160(msg.sender))).transfer(_fundedValues[tokenId]);
    // Emit a Withdraw event
    emit Withdraw(msg.sender, _fundedValues[tokenId], tokenId);
    // Set the coin's funded value to nil
    _fundedValues[tokenId] = uint256(0);
  }

  function allowBuy(uint256 tokenId, uint256 price) external {
    // Make sure the coin exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Only the token owner may invoke
    require(_isOwner(tokenId), SENDER_MUST_BE_TOKEN_OWNER);
    // Listing price must be at least as much as the face value
    require(price >= _faceValue, PRICE_MUST_BE_AT_LEAST_FACE_VALUE);
    // Token must be funded
    require(_fundedValues[tokenId] == _faceValue, TOKEN_MUST_BE_FUNDED);
    _listPrices[tokenId] = price;

    emit OnMarket(tokenId, price);
  }

  function disallowBuy(uint256 tokenId) external {
    // Ensure the coin exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Only the token owner may invoke
    require(_isOwner(tokenId), SENDER_MUST_BE_TOKEN_OWNER);
    // Token must be funded
    require(_fundedValues[tokenId] == _faceValue, TOKEN_MUST_BE_FUNDED);
    // Delist the coin if listed
    _disallowBuy(tokenId);
  }

  function _disallowBuy(uint256 tokenId) internal {
    if (_listPrices[tokenId] != uint256(0)) {
      _listPrices[tokenId] = uint256(0);

      emit OffMarket(tokenId);
    }
  }

  function buy(uint256 tokenId) nonReentrant external payable {
    // Ensure the coin exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Capture the seller
    address seller = ownerOf(tokenId);
    // Require that the buyer is not the seller
    require(seller != msg.sender, BUYER_CANNOT_BE_OWNER);
    // Require that the coins is on sale
    require(_listPrices[tokenId] >= _faceValue, TOKEN_PRICE_MUST_BE_AT_LEAST_FACE_VALUE);
    // Require that there is enough Ether in the transaction
    require(msg.value == _listPrices[tokenId], MESSAGE_VALUE_MUST_EQUAL_PRICE); // TODO : test buy for less than price

    BaseERC721._buy(tokenId);

    safeTransferFrom(seller, msg.sender, tokenId);
    // Transfer the payment to the seller
    payable(seller).transfer(msg.value);

    _listPrices[tokenId] = uint256(0);

    emit Purchase(seller, msg.sender, tokenId, msg.value);
  }

  /// @notice Returns all the relevant information about a specific coin.
  function getCoin(uint256 tokenId) external view
  returns (
    bool forSale,
    bool bestowed,
    uint256 price,
    uint256 fundedValue,
    string memory uri,
    address owner
  ) {
    price = _listPrices[tokenId];
    forSale = price != uint256(0);
    fundedValue = _fundedValues[tokenId];
    bestowed = isBestowed(tokenId);

    if (_exists(tokenId)) {
      owner = ownerOf(tokenId);
      uri = tokenURI(tokenId);
    }
    else {
      owner = address(0);
      uri = '';
    }
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(Giftable) {
    if (_exists(tokenId)) {
      _disallowBuy(tokenId);
    }

    super._beforeTokenTransfer(from, to, tokenId);
  }

  function gift(
    uint256 tokenId,
    uint256 phoneNumber
  ) external {
    // Ensure the coin exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Only the token owner may invoke
    require(_isOwner(tokenId), SENDER_MUST_BE_TOKEN_OWNER);
    // Token must be funded
    require(_fundedValues[tokenId] == _faceValue, TOKEN_MUST_BE_FUNDED);
    // Token must not be for sale
    require(_listPrices[tokenId] == uint256(0), TOKEN_MUST_NOT_BE_FOR_SALE);

    _gift(tokenId, phoneNumber);
  }

  function ungift(uint256 tokenId) external {
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    require(_isOwner(tokenId) || _isMinter(), SENDER_MUST_BE_TOKEN_OWNER);

    _ungift(tokenId);
  }

  function authoriseGiftRecipient(uint256 tokenId, address recipient) onlyMinter external {
    // Ensure the coin exists
    require(_exists(tokenId), TOKEN_ID_DOES_NOT_EXIST);
    // Token must be funded
    require(_fundedValues[tokenId] == _faceValue, TOKEN_MUST_BE_FUNDED);

    _authoriseGiftRecipient(tokenId, recipient);
  }
}

// 24.576 (target)

// 26.8 <--
// 27.97
// 27.22 (no strings)
// 25.34
// 24.96
// 24.88
// 25.04
// 24.75
// 24.19
// 24.06
// 23.51 (no moniker)
// 24.38
// 24.24
// 23.92 (*)
// 23.85
// 24.00
