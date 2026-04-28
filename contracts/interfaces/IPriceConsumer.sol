// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IPriceConsumer
/// @notice Interface para consumo de preço externo via oráculo
interface IPriceConsumer {
    /// @notice Retorna o último preço ETH/USD com 8 casas decimais
    /// @return price Preço em USD (ex: 200000000000 = $2000.00)
    function getLatestPrice() external view returns (int256 price);

    /// @notice Retorna o timestamp da última atualização do feed
    function getLastUpdateTime() external view returns (uint256);
}
