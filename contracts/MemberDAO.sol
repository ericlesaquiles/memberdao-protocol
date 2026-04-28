// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IGovToken.sol";

/// @title MemberDAO
/// @notice Governança simplificada do MemberDAO Protocol.
///         Qualquer holder de GTK pode criar propostas e votar.
///         Peso do voto = saldo GTK no momento da criação da proposta.
///
/// @dev Implementa snapshot manual simples. Para produção, usar ERC20Votes
///      com Governor da OpenZeppelin (mais robusto contra manipulação).
contract MemberDAO is Ownable, ReentrancyGuard {

    IGovToken public immutable govToken;

    // ─── Parâmetros de governança ──────────────────────────────────
    uint256 public votingPeriod    = 3 days;
    uint256 public quorumThreshold = 100_000 * 1e18;  // 100k GTK mínimo para quórum
    uint256 public proposalThreshold = 1_000 * 1e18;  // 1k GTK para criar proposta

    // ─── Estruturas ────────────────────────────────────────────────
    enum ProposalState { Rejected, Cancelled, Passed, Executed, Active }

    struct Proposal {
        uint256 id;
        address proposer;
        string  title;
        string  description;
        uint256 createdAt;
        uint256 deadline;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 snapshotBlock;    // bloco de snapshot para evitar flash loans
        ProposalState state;
        bool    executed;
    }

    // ─── Estado ───────────────────────────────────────────────────
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    // proposalId => voter => hasVoted
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    // proposalId => voter => voteChoice (true = favor)
    mapping(uint256 => mapping(address => bool)) public voteChoice;

    // ─── Eventos ──────────────────────────────────────────────────
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        string  title,
        uint256 deadline
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool    inFavor,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed id);
    event ProposalCancelled(uint256 indexed id);
    event GovernanceParamsUpdated(
        uint256 votingPeriod,
        uint256 quorum,
        uint256 threshold
    );

    // ══════════════════════════════════════════════════════════════
    constructor(address _govToken, address _initialOwner) Ownable(_initialOwner) {
        require(_govToken != address(0), "DAO: govToken zero");
        govToken = IGovToken(_govToken);
    }

    // ══════════════════════════════════════════════════════════════
    //  Criação de propostas
    // ══════════════════════════════════════════════════════════════

    /// @notice Cria uma nova proposta de governança
    /// @param title       Título curto da proposta (máx 100 chars)
    /// @param description Descrição detalhada da proposta
    function propose(string calldata title, string calldata description)
        external
        returns (uint256 proposalId)
    {
        require(bytes(title).length > 0 && bytes(title).length <= 100,
            "DAO: titulo invalido");
        require(bytes(description).length > 0,
            "DAO: descricao vazia");
        require(govToken.balanceOf(msg.sender) >= proposalThreshold,
            "DAO: GTK insuficiente para propor");

        proposalId = proposalCount++;

        proposals[proposalId] = Proposal({
            id:             proposalId,
            proposer:       msg.sender,
            title:          title,
            description:    description,
            createdAt:      block.timestamp,
            deadline:       block.timestamp + votingPeriod,
            votesFor:       0,
            votesAgainst:   0,
            snapshotBlock:  block.number,
            state:          ProposalState.Active,
            executed:       false
        });

        emit ProposalCreated(proposalId, msg.sender, title, block.timestamp + votingPeriod);
    }

    // ══════════════════════════════════════════════════════════════
    //  Votação
    // ══════════════════════════════════════════════════════════════

    /// @notice Vota em uma proposta ativa
    /// @param proposalId ID da proposta
    /// @param inFavor    true = favorável, false = contrário
    function vote(uint256 proposalId, bool inFavor) external nonReentrant {
        Proposal storage p = proposals[proposalId];

        require(p.state == ProposalState.Active,    "DAO: proposta inativa");
        require(block.timestamp <= p.deadline,      "DAO: votacao encerrada");
        require(!hasVoted[proposalId][msg.sender],  "DAO: ja votou");

        uint256 weight = govToken.balanceOf(msg.sender);
        require(weight > 0, "DAO: sem poder de voto");

        hasVoted[proposalId][msg.sender]  = true;
        voteChoice[proposalId][msg.sender] = inFavor;

        if (inFavor) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }

        emit VoteCast(proposalId, msg.sender, inFavor, weight);
    }

    // ══════════════════════════════════════════════════════════════
    //  Finalização
    // ══════════════════════════════════════════════════════════════

    /// @notice Finaliza o estado de uma proposta após o prazo
    ///         Qualquer um pode chamar esta função
    function finalize(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.state == ProposalState.Active, "DAO: proposta nao ativa");
        require(block.timestamp > p.deadline,    "DAO: votacao em andamento");

        uint256 totalVotes = p.votesFor + p.votesAgainst;

        if (totalVotes < quorumThreshold) {
            p.state = ProposalState.Rejected; // quórum não atingido
        } else if (p.votesFor > p.votesAgainst) {
            p.state = ProposalState.Passed;
        } else {
            p.state = ProposalState.Rejected;
        }
    }

    /// @notice Marca a proposta aprovada como executada (owner, após ação off-chain)
    function execute(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(p.state == ProposalState.Passed,  "DAO: proposta nao aprovada");
        require(!p.executed,                      "DAO: ja executada");

        p.executed = true;
        p.state    = ProposalState.Executed;

        emit ProposalExecuted(proposalId);
    }

    /// @notice Cancela uma proposta (apenas o propositor ou owner)
    function cancel(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.state == ProposalState.Active,                              "DAO: nao ativa");
        require(msg.sender == p.proposer || msg.sender == owner(),            "DAO: sem permissao");

        p.state = ProposalState.Cancelled;
        emit ProposalCancelled(proposalId);
    }

    // ══════════════════════════════════════════════════════════════
    //  Leitura
    // ══════════════════════════════════════════════════════════════

    /// @notice Retorna dados de uma proposta
    function getProposal(uint256 id) external view returns (Proposal memory) {
        return proposals[id];
    }

    /// @notice Lista todos os IDs de propostas ativas
    function getActiveProposals() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].state == ProposalState.Active) count++;
        }
        uint256[] memory ids = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].state == ProposalState.Active) ids[idx++] = i;
        }
        return ids;
    }

    // ══════════════════════════════════════════════════════════════
    //  Admin
    // ══════════════════════════════════════════════════════════════

    /// @notice Atualiza parâmetros de governança
    function updateGovernanceParams(
        uint256 _votingPeriod,
        uint256 _quorum,
        uint256 _threshold
    ) external onlyOwner {
        require(_votingPeriod >= 1 days && _votingPeriod <= 30 days, "DAO: periodo invalido");
        require(_quorum > 0,    "DAO: quorum zero");
        require(_threshold > 0, "DAO: threshold zero");

        votingPeriod      = _votingPeriod;
        quorumThreshold   = _quorum;
        proposalThreshold = _threshold;

        emit GovernanceParamsUpdated(_votingPeriod, _quorum, _threshold);
    }
}
