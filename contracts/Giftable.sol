// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./BaseERC721.sol";

abstract contract Giftable is BaseERC721 {
  string constant TOKEN_MUST_NOT_BE_BESTOWED = '';
  string constant TOKEN_MUST_BE_BESTOWED = '';

  mapping(uint256 => uint256) private _giftRecipientPhone;
  mapping(uint256 => address) private _giftRecipientAddr;

  function getRecipientPhone(uint256 tokenId) public view returns (uint256) {
    require(_isOwner(tokenId) || _isMinter());
    return _giftRecipientPhone[tokenId];
  }

  function isBestowed(uint256 tokenId) public view virtual returns (bool) {
    return (_giftRecipientPhone[tokenId] != 0);
  }

  function _gift(
    uint256 tokenId,
    uint256 phoneNumber
  ) internal {
    require(isBestowed(tokenId) == false, TOKEN_MUST_NOT_BE_BESTOWED);

    _giftRecipientPhone[tokenId] = phoneNumber;
  }

  function _ungift(uint256 tokenId) internal {
    delete _giftRecipientPhone[tokenId];
    delete _giftRecipientAddr[tokenId];
  }

  function _authoriseGiftRecipient(uint256 tokenId, address recipient) internal {
    // Token must be gifted
    require(isBestowed(tokenId), TOKEN_MUST_BE_BESTOWED);
    // Stash the recipient addr
    _giftRecipientAddr[tokenId] = recipient;
    // Approve the transfer
    ERC721._approve(msg.sender, tokenId);
    // Transfer the token
    safeTransferFrom(ownerOf(tokenId), recipient, tokenId);
    // Delete gift recipient
    _ungift(tokenId);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(BaseERC721) {
    if (isBestowed(tokenId)) {
      require(to == _giftRecipientAddr[tokenId], "");
    }

    super._beforeTokenTransfer(from, to, tokenId);
  }
}
