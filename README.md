# MemberDAO Protocol

MVP completo de protocolo Web3 descentralizado desenvolvido para o projeto da Residência em TIC 29 - Web 3.0 (Unidade 1 | Capítulo 5).

## 📐 Arquitetura

```
contracts/
├── GovToken.sol          # ERC-20 com ERC20Votes (GTK)
├── MemberPassNFT.sol     # ERC-721 credencial de membro
├── PriceConsumer.sol     # Oráculo Chainlink ETH/USD
├── StakingPool.sol       # Staking com recompensa dinâmica
├── MemberDAO.sol         # Governança DAO simplificada
├── interfaces/
│   ├── IGovToken.sol
│   └── IPriceConsumer.sol
└── mocks/
    └── MockPriceConsumer.sol

scripts/
└── deploy.js             # Deploy completo na Sepolia

frontend/
├── index.html            # dApp com ethers.js
└── addresses.json        # gerado automaticamente pelo deploy
```

## 🚀 Setup

### Pré-requisitos
- Node.js >= 18
- npm
- MetaMask configurado na Sepolia
- ETH de teste: https://sepoliafaucet.com

### Instalação

```bash
npm install
```

### Configurar variáveis de ambiente

```bash
cp .env.example .env
```

Preencher `.env`:
```
PRIVATE_KEY=sua_chave_privada_aqui
SEPOLIA_RPC=https://sepolia.infura.io/v3/SEU_ID
ETHERSCAN_KEY=sua_chave_etherscan
```

### Compilar

```bash
npm run compile
```

### Testes

```bash
npm test
```

### Deploy local (Hardhat node)

```bash
# Terminal 1
npm run node

# Terminal 2
npm run deploy:local
```

### Deploy na Sepolia

```bash
npm run deploy:sepolia
```

O script gera `frontend/addresses.json` automaticamente com todos os endereços e links do Etherscan.

### Verificar contratos no Etherscan

```bash
npx hardhat verify --network sepolia ENDERECO_DO_CONTRATO "arg1" "arg2"
```

## 🖥 Frontend

Abra `frontend/index.html` no navegador (pode usar Live Server do VS Code).
Dica: Se abrir esse arquivo com `file://home (...)`, ele será incapaz de encontrar o Metamask, por design do próprio Metamask que só se conecta com páginas seguindo protocolo `http` ou `https`.
Uma _easy fix_ é rodar um servidor no python com `python3 -m http.server 3000` na pasta `frontend` (ie, `cd frontend; python3 -m http.server 3000`), e acessar a página por `http://localhost:3000/`.

Depois disso,

1. Conecte o MetaMask na Sepolia
2. Vá na aba **Info** e cole os endereços dos contratos após o deploy
3. Clique em **Salvar & Conectar Contratos**
4. Use as abas NFT → Token → Staking → DAO

## 🔐 Segurança

- **ReentrancyGuard** em todas as funções que movem tokens
- **CEI pattern** (Checks-Effects-Interactions) em todas as transações
- **AccessControl** para MINTER_ROLE (somente StakingPool minta GTK)
- **Validação de oráculo** com verificação de staleness (> 1h reverte)
- **Solidity ^0.8.20** (overflow/underflow checked por padrão)
- **try/catch** no oráculo com fallback para BASE_RATE

## 🔗 Chainlink

- Feed ETH/USD Sepolia: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
- Tolerância de staleness: 3600 segundos (1 hora)
- O `rewardRate` do staking é calculado como `BASE_RATE × 1e8 / ethPrice`

## 📊 Rubrica atendida

| Critério               | Implementação                                         |
|------------------------|-------------------------------------------------------|
| Token ERC-20           | `GovToken.sol` com ERC20Votes e AccessControl        |
| NFT ERC-721            | `MemberPassNFT.sol` com soulbound opcional           |
| Staking                | `StakingPool.sol` com reward-per-token acumulado     |
| Governança DAO         | `MemberDAO.sol` com propostas, votação e quórum      |
| Oráculo                | `PriceConsumer.sol` integrado ao Chainlink ETH/USD   |
| Backend Web3           | `scripts/deploy.js` com ethers.js v6                 |
| Frontend Web3          | `frontend/index.html` com ethers.js v6               |
| Deploy testnet         | Configurado para Sepolia via Hardhat                  |
| Segurança              | ReentrancyGuard, CEI, AccessControl, ^0.8.20         |

## 📄 Licença

MIT
