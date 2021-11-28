// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";

abstract contract BaseERC721 is ERC721Enumerable, ERC721Pausable, Ownable, AccessControl {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;

  string private __baseURI;
  string private _contractURI;

  uint256 public mintLimit;
  uint256 public numberMinted;

  string constant MINT_LIMIT_REACHED = ""; // "mint limit reacted";
  string constant SENDER_MUST_BE_MINTER = ""; // "Caller not minter";

  constructor (
    string memory name,
    string memory symbol,
    uint256 __mintLimit,
    string memory baseURI,
    string memory __contractURI
  ) ERC721(name, symbol) {
    _setupRole(MINTER_ROLE, msg.sender);
    mintLimit = __mintLimit;
    __baseURI = baseURI;
    _contractURI = __contractURI;
  }

  // Opensea custom method
  function contractURI() public view returns (string memory) {
    return _contractURI;
  }

  function _baseURI() internal view override(ERC721) returns (string memory) {
    return __baseURI;
  }

  modifier onlyMinter {
    require(_isMinter(), SENDER_MUST_BE_MINTER);
    _;
  }

  function _isMinter() internal view returns(bool) {
    return hasRole(MINTER_ROLE, msg.sender);
  }

  function _isOwner(uint256 _tokenId) internal view returns(bool) {
    return msg.sender == ownerOf(_tokenId);
  }

  function _mint() internal virtual onlyMinter returns (uint256) {
    require(numberMinted < mintLimit, MINT_LIMIT_REACHED);
    _tokenIds.increment();
    uint256 tokenId = _tokenIds.current();

    ERC721._safeMint(msg.sender, tokenId);
    numberMinted++;

    return tokenId;
  }

  function _buy(uint256 tokenId) internal {
    ERC721._approve(msg.sender, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual
    override(ERC721, ERC721Enumerable, AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC721Enumerable, ERC721Pausable) {
    super._beforeTokenTransfer(from, to, amount);
  }
}
