// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IGovToken.sol";
import "./interfaces/IPriceConsumer.sol";

/// @title StakingPool
/// @notice Pool de staking de GTK com recompensas dinâmicas ajustadas pelo preço ETH/USD.
///         Requer posse de MemberPass NFT para participar.
///
/// @dev Usa o modelo reward-per-token acumulado (padrão Synthetix):
///      - rewardPerTokenStored cresce globalmente com o tempo
///      - cada usuário armazena seu "paid" snapshot e calcula o delta
///      Complexidade O(1) por usuário, independente do número de stakers.
contract StakingPool is Ownable, ReentrancyGuard {

    // ─── Interfaces ────────────────────────────────────────────────
    IGovToken      public immutable govToken;
    IERC721        public immutable memberPass;
    IPriceConsumer public immutable priceConsumer;

    // ─── Parâmetros de recompensa ──────────────────────────────────
    /// @notice Taxa base: 1 GTK por segundo quando ETH = $1
    uint256 public constant BASE_RATE = 1e18;
    uint256 public constant MIN_RATE  = 1e16;  // 0.01 GTK/s (mínimo)
    uint256 public constant MAX_RATE  = 5e18;  // 5.00 GTK/s (máximo)

    // ─── Estado global ─────────────────────────────────────────────
    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;

    // ─── Estado por usuário ────────────────────────────────────────
    struct UserInfo {
        uint256 staked;
        uint256 rewardPerTokenPaid;
        uint256 pendingRewards;
    }
    mapping(address => UserInfo) public users;

    // ─── Eventos ───────────────────────────────────────────────────
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate, uint256 ethPriceUSD);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    // ══════════════════════════════════════════════════════════════
    constructor(
        address _govToken,
        address _memberPass,
        address _priceConsumer,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_govToken      != address(0), "Staking: govToken zero");
        require(_memberPass    != address(0), "Staking: memberPass zero");
        require(_priceConsumer != address(0), "Staking: oracle zero");

        govToken      = IGovToken(_govToken);
        memberPass    = IERC721(_memberPass);
        priceConsumer = IPriceConsumer(_priceConsumer);
        lastUpdateTime = block.timestamp;
    }

    // ══════════════════════════════════════════════════════════════
    //  Funções públicas
    // ══════════════════════════════════════════════════════════════

    /// @notice Deposita GTK no pool. Requer MemberPass NFT.
    /// @param amount Quantidade de GTK em wei
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0,                              "Staking: amount = 0");
        require(memberPass.balanceOf(msg.sender) > 0,   "Staking: requer MemberPass NFT");

        _updateRewards(msg.sender);

        users[msg.sender].staked += amount;
        totalStaked += amount;

        // Checks-Effects-Interactions: estado já atualizado, agora interage
        bool ok = IERC20(address(govToken)).transferFrom(msg.sender, address(this), amount);
        require(ok, "Staking: transferencia falhou");

        emit Staked(msg.sender, amount);
    }

    /// @notice Retira GTK do pool (recompensas permanecem pendentes)
    /// @param amount Quantidade de GTK em wei
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0,                              "Staking: amount = 0");
        require(users[msg.sender].staked >= amount,      "Staking: saldo insuficiente");

        _updateRewards(msg.sender);

        users[msg.sender].staked -= amount;
        totalStaked -= amount;

        bool ok = IERC20(address(govToken)).transfer(msg.sender, amount);
        require(ok, "Staking: transferencia falhou");

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Saca todas as recompensas acumuladas (mint de novos GTK)
    function claimRewards() external nonReentrant {
        _updateRewards(msg.sender);

        uint256 reward = users[msg.sender].pendingRewards;
        require(reward > 0, "Staking: nenhuma recompensa");

        // CEI: zera antes de mintar
        users[msg.sender].pendingRewards = 0;
        govToken.mint(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    /// @notice Retira stake + recompensas em uma única transação
    function exit() external nonReentrant {
        _updateRewards(msg.sender);

        uint256 stakedAmt = users[msg.sender].staked;
        uint256 reward    = users[msg.sender].pendingRewards;

        if (stakedAmt > 0) {
            users[msg.sender].staked = 0;
            totalStaked -= stakedAmt;
            bool ok = IERC20(address(govToken)).transfer(msg.sender, stakedAmt);
            require(ok, "Staking: transferencia falhou");
            emit Withdrawn(msg.sender, stakedAmt);
        }

        if (reward > 0) {
            users[msg.sender].pendingRewards = 0;
            govToken.mint(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward);
        }
    }

    /// @notice Saque de emergência — retira stake sem coletar recompensas
    function emergencyWithdraw() external nonReentrant {
        uint256 amount = users[msg.sender].staked;
        require(amount > 0, "Staking: sem stake");

        users[msg.sender].staked            = 0;
        users[msg.sender].pendingRewards    = 0;
        users[msg.sender].rewardPerTokenPaid = 0;
        totalStaked -= amount;

        bool ok = IERC20(address(govToken)).transfer(msg.sender, amount);
        require(ok, "Staking: transferencia falhou");

        emit EmergencyWithdraw(msg.sender, amount);
    }

    // ══════════════════════════════════════════════════════════════
    //  Funções de leitura
    // ══════════════════════════════════════════════════════════════

    /// @notice Acumulador global de recompensa por token (com decimais ×1e18)
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        uint256 elapsed = block.timestamp - lastUpdateTime;
        uint256 rate    = _currentRewardRate();
        return rewardPerTokenStored + (rate * elapsed * 1e18) / totalStaked;
    }

    /// @notice Recompensas pendentes de um endereço (em GTK wei)
    function earned(address account) public view returns (uint256) {
        UserInfo memory u = users[account];
        return u.pendingRewards
            + (u.staked * (rewardPerToken() - u.rewardPerTokenPaid)) / 1e18;
    }

    /// @notice Taxa de recompensa atual em GTK/segundo
    function currentRewardRate() external view returns (uint256) {
        return _currentRewardRate();
    }

    /// @notice Preço ETH/USD atual do oráculo (8 decimais)
    function currentEthPrice() external view returns (int256) {
        return priceConsumer.getLatestPrice();
    }

    // ══════════════════════════════════════════════════════════════
    //  Lógica interna
    // ══════════════════════════════════════════════════════════════

    /// @dev Atualiza acumulador global + pendentes do usuário.
    ///      DEVE ser chamado no início de qualquer função que altere saldo.
    function _updateRewards(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime       = block.timestamp;

        if (account != address(0)) {
            users[account].pendingRewards     = earned(account);
            users[account].rewardPerTokenPaid = rewardPerTokenStored;
        }

        _emitRateUpdate();
    }

    /// @dev Taxa de recompensa inversamente proporcional ao preço ETH (com limites)
    function _currentRewardRate() internal view returns (uint256) {
        try priceConsumer.getLatestPrice() returns (int256 price) {
            if (price <= 0) return BASE_RATE;
            // rate = BASE_RATE × 1e8 / price  (ambos em unidades compatíveis)
            uint256 rate = (BASE_RATE * 1e8) / uint256(price);
            if (rate < MIN_RATE) return MIN_RATE;
            if (rate > MAX_RATE) return MAX_RATE;
            return rate;
        } catch {
            return BASE_RATE; // fallback se oráculo falhar
        }
    }

    function _emitRateUpdate() internal {
        try priceConsumer.getLatestPrice() returns (int256 price) {
            emit RewardRateUpdated(_currentRewardRate(), uint256(price));
        } catch {}
    }
}
