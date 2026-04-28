// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title GovToken
/// @notice Token ERC-20 de governança do MemberDAO Protocol
/// @dev Usa ERC20Votes para snapshots de votação e AccessControl para mint seguro.
///      Somente endereços com MINTER_ROLE (ex: StakingPool) podem criar novos tokens.
contract GovToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, AccessControl {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Supply inicial distribuído ao deployer para bootstrap do protocolo
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 1e18; // 1 milhão de GTK

    // ─── Eventos ──────────────────────────────────────────────────
    event MinterGranted(address indexed minter);
    event MinterRevoked(address indexed minter);

    // ══════════════════════════════════════════════════════════════
    /// @param initialOwner Endereço que recebe DEFAULT_ADMIN_ROLE e o supply inicial
    constructor(address initialOwner)
        ERC20("GovToken", "GTK")
        ERC20Permit("GovToken")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, initialOwner);

        // Minta o supply inicial para o owner (distribuição / liquidity bootstrap)
        _mint(initialOwner, INITIAL_SUPPLY);

        // Auto-delega votos para que o owner possa votar de imediato
        _delegate(initialOwner, initialOwner);
    }

    // ══════════════════════════════════════════════════════════════
    //  Funções externas
    // ══════════════════════════════════════════════════════════════

    /// @notice Minta novos GTK — reservado ao StakingPool como recompensa
    /// @param to      Destinatário dos tokens
    /// @param amount  Quantidade em wei (18 decimais)
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // ══════════════════════════════════════════════════════════════
    //  Overrides obrigatórios (ERC20 + ERC20Votes + ERC20Permit)
    // ══════════════════════════════════════════════════════════════

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
