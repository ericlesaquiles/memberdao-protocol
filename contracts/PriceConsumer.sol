// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title PriceConsumer
/// @notice Consome o feed ETH/USD da Chainlink e expõe o preço para o StakingPool.
///         Feed na Sepolia: 0x694AA1769357215DE4FAC081bf1f309aDC325306
contract PriceConsumer is Ownable {

    AggregatorV3Interface public immutable priceFeed;

    /// @notice Tolerância máxima de staleness do feed (1 hora)
    uint256 public constant MAX_STALENESS = 3600;

    // ─── Eventos ──────────────────────────────────────────────────
    event PriceFetched(int256 price, uint256 updatedAt);

    // ══════════════════════════════════════════════════════════════
    /// @param _feed Endereço do AggregatorV3 na rede alvo
    constructor(address _feed, address initialOwner) Ownable(initialOwner) {
        require(_feed != address(0), "PriceConsumer: feed invalido");
        priceFeed = AggregatorV3Interface(_feed);
    }

    // ══════════════════════════════════════════════════════════════
    //  Funções públicas
    // ══════════════════════════════════════════════════════════════

    /// @notice Retorna o último preço ETH/USD com 8 casas decimais.
    ///         Reverte se o dado estiver desatualizado (> 1 hora).
    function getLatestPrice() external view returns (int256 price) {
        (
            uint80 roundId,
            int256 _price,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        require(_price > 0,                          "PriceConsumer: preco invalido");
        require(updatedAt > 0,                       "PriceConsumer: round incompleto");
        require(answeredInRound >= roundId,           "PriceConsumer: dado desatualizado");
        require(block.timestamp - updatedAt < MAX_STALENESS, "PriceConsumer: feed stale");

        return _price;
    }

    /// @notice Retorna o timestamp da última atualização do feed
    function getLastUpdateTime() external view returns (uint256) {
        (, , , uint256 updatedAt, ) = priceFeed.latestRoundData();
        return updatedAt;
    }

    /// @notice Retorna o número de decimais do feed (padrão Chainlink = 8)
    function decimals() external view returns (uint8) {
        return priceFeed.decimals();
    }

    /// @notice Retorna a descrição do par (ex: "ETH / USD")
    function description() external view returns (string memory) {
        return priceFeed.description();
    }
}
