// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
//import "@openzeppelin/contracts/utils/Counters.sol";

/// @title MemberPassNFT
/// @notice Credencial ERC-721 de acesso ao MemberDAO Protocol.
///         Cada endereço pode mintar exatamente 1 NFT (soulbound opcional).
contract MemberPassNFT is ERC721, ERC721URIStorage, Ownable {

    uint256 private _nextTokenId;

    /// @notice Preço de mint em ETH
    uint256 public mintPrice = 0.01 ether;

    /// @notice URI base dos metadados (IPFS)
    string public baseTokenURI;

    /// @notice Controla se o NFT é não-transferível após mint (soulbound)
    bool public soulbound = false;

    // ─── Mappings ─────────────────────────────────────────────────
    mapping(address => bool) public hasMinted;

    // ─── Eventos ──────────────────────────────────────────────────
    event MemberMinted(address indexed member, uint256 tokenId);
    event MintPriceUpdated(uint256 newPrice);
    event Withdrawn(address indexed to, uint256 amount);

    // ══════════════════════════════════════════════════════════════
    constructor(address initialOwner, string memory _baseURI)
        ERC721("MemberPass", "MPASS")
        Ownable(initialOwner)
    {
        baseTokenURI = _baseURI;
    }

    // ══════════════════════════════════════════════════════════════
    //  Funções públicas
    // ══════════════════════════════════════════════════════════════

    /// @notice Minta o MemberPass. Cada endereço pode mintar apenas 1.
    function mint() external payable {
        require(!hasMinted[msg.sender], "MemberPass: ja possui NFT");
        require(msg.value >= mintPrice, "MemberPass: ETH insuficiente");

        hasMinted[msg.sender] = true;
        uint256 tokenId = _nextTokenId++;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked(baseTokenURI, _toString(tokenId))));

        emit MemberMinted(msg.sender, tokenId);
    }

    /// @notice Mint gratuito para endereços permitidos (owner apenas)
    function mintFree(address to) external onlyOwner {
        require(!hasMinted[to], "MemberPass: ja possui NFT");
        hasMinted[to] = true;
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked(baseTokenURI, _toString(tokenId))));
        emit MemberMinted(to, tokenId);
    }

    // ══════════════════════════════════════════════════════════════
    //  Admin
    // ══════════════════════════════════════════════════════════════

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
        emit MintPriceUpdated(_price);
    }

    function setSoulbound(bool _soulbound) external onlyOwner {
        soulbound = _soulbound;
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseTokenURI = _baseURI;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool ok, ) = payable(owner()).call{value: balance}("");
        require(ok, "MemberPass: withdraw falhou");
        emit Withdrawn(owner(), balance);
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    // ══════════════════════════════════════════════════════════════
    //  Overrides obrigatórios
    // ══════════════════════════════════════════════════════════════

    /// @dev Bloqueia transferências se soulbound estiver ativo
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721)
        returns (address)
    {
        address from = _ownerOf(tokenId);
        if (soulbound && from != address(0) && to != address(0)) {
            revert("MemberPass: token nao transferivel (soulbound)");
        }
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId)
        public view override(ERC721, ERC721URIStorage) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721URIStorage) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ── Utilitário interno ──────────────────────────────────────
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
