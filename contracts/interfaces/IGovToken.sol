// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IGovToken
/// @notice Interface do token de governança com mint controlado
interface IGovToken is IERC20 {
    /// @notice Minta novos tokens para um endereço (apenas MINTER_ROLE)
    function mint(address to, uint256 amount) external;

    /// @notice Queima tokens do próprio saldo
    function burn(uint256 amount) external;

    /// @notice Retorna o total de votos delegados a um endereço (snapshot)
    function getVotes(address account) external view returns (uint256);

    /// @notice Delega poder de voto
    function delegate(address delegatee) external;
}
