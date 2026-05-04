// scripts/deploy.js
// Deploy completo do MemberDAO Protocol na Sepolia
// Uso: npx hardhat run scripts/deploy.js --network sepolia

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// ── Configuração ──────────────────────────────────────────────────────────────
// Feed ETH/USD Chainlink na Sepolia
const CHAINLINK_ETH_USD_SEPOLIA = "0x694AA1769357215DE4FAC081bf1f309aDC325306";

// URI base dos metadados do NFT (IPFS ou servidor)
const BASE_NFT_URI = "ipfs://QmYOURCIDHERE/";

// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("\n╔══════════════════════════════════════════════╗");
  console.log("║     MemberDAO Protocol — Deploy Script      ║");
  console.log("╚══════════════════════════════════════════════╝");
  console.log(`\n► Deployer : ${deployer.address}`);
  console.log(`► Rede     : ${(await ethers.provider.getNetwork()).name}`);
  console.log(`► Saldo    : ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH\n`);

  // ── 1. GovToken ─────────────────────────────────────────────────────────────
  process.stdout.write("1/5 Deployando GovToken (GTK)... ");
  const GovToken = await ethers.getContractFactory("GovToken");
  const govToken = await GovToken.deploy(deployer.address);
  await govToken.waitForDeployment();
  const govTokenAddr = await govToken.getAddress();
  console.log(`✓ ${govTokenAddr}`);

  // ── 2. MemberPassNFT ────────────────────────────────────────────────────────
  process.stdout.write("2/5 Deployando MemberPassNFT (MPASS)... ");
  const MemberPassNFT = await ethers.getContractFactory("MemberPassNFT");
  const memberPass = await MemberPassNFT.deploy(deployer.address, BASE_NFT_URI);
  await memberPass.waitForDeployment();
  const memberPassAddr = await memberPass.getAddress();
  console.log(`✓ ${memberPassAddr}`);

  // ── 3. PriceConsumer ────────────────────────────────────────────────────────
  process.stdout.write("3/5 Deployando PriceConsumer (Chainlink)... ");
  const PriceConsumer = await ethers.getContractFactory("PriceConsumer");
  const priceConsumer = await PriceConsumer.deploy(
    CHAINLINK_ETH_USD_SEPOLIA,
    deployer.address
  );
  await priceConsumer.waitForDeployment();
  const priceConsumerAddr = await priceConsumer.getAddress();
  console.log(`✓ ${priceConsumerAddr}`);

  // ── 4. StakingPool ──────────────────────────────────────────────────────────
  process.stdout.write("4/5 Deployando StakingPool... ");
  const StakingPool = await ethers.getContractFactory("StakingPool");
  const stakingPool = await StakingPool.deploy(
    govTokenAddr,
    memberPassAddr,
    priceConsumerAddr,
    deployer.address
  );
  await stakingPool.waitForDeployment();
  const stakingPoolAddr = await stakingPool.getAddress();
  console.log(`✓ ${stakingPoolAddr}`);

  // ── 5. MemberDAO ────────────────────────────────────────────────────────────
  process.stdout.write("5/5 Deployando MemberDAO... ");
  const MemberDAO = await ethers.getContractFactory("MemberDAO");
  const memberDAO = await MemberDAO.deploy(govTokenAddr, deployer.address);
  await memberDAO.waitForDeployment();
  const memberDAOAddr = await memberDAO.getAddress();
  console.log(`✓ ${memberDAOAddr}`);

  // ── Configuração pós-deploy ──────────────────────────────────────────────────
  console.log("\n► Configurando permissões...");

  // Concede MINTER_ROLE ao StakingPool via AccessControl padrão
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const tx1 = await govToken.grantRole(MINTER_ROLE, stakingPoolAddr);
  await tx1.wait();
  console.log("  ✓ MINTER_ROLE concedido ao StakingPool");

  // Mint inicial de GTK para o deployer já delegado (feito no constructor)
  console.log("  ✓ Supply inicial de 1.000.000 GTK mintado ao deployer");

  // ── Salva endereços em arquivo ──────────────────────────────────────────────
  const addresses = {
    network:       (await ethers.provider.getNetwork()).name,
    deployedAt:    new Date().toISOString(),
    deployer:      deployer.address,
    contracts: {
      GovToken:      govTokenAddr,
      MemberPassNFT: memberPassAddr,
      PriceConsumer: priceConsumerAddr,
      StakingPool:   stakingPoolAddr,
      MemberDAO:     memberDAOAddr,
    },
    chainlink: {
      ETH_USD_feed: CHAINLINK_ETH_USD_SEPOLIA,
    },
    explorer: {
      GovToken:      `https://sepolia.etherscan.io/address/${govTokenAddr}`,
      MemberPassNFT: `https://sepolia.etherscan.io/address/${memberPassAddr}`,
      PriceConsumer: `https://sepolia.etherscan.io/address/${priceConsumerAddr}`,
      StakingPool:   `https://sepolia.etherscan.io/address/${stakingPoolAddr}`,
      MemberDAO:     `https://sepolia.etherscan.io/address/${memberDAOAddr}`,
    }
  };

  const outPath = path.join(__dirname, "../frontend/addresses.json");
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(addresses, null, 2));

  // ── Resumo ──────────────────────────────────────────────────────────────────
  console.log("\n╔══════════════════════════════════════════════╗");
  console.log("║              Deploy Concluído!               ║");
  console.log("╚══════════════════════════════════════════════╝");
  console.log("\n📄 Endereços dos Contratos:");
  console.log(`  GovToken      : ${govTokenAddr}`);
  console.log(`  MemberPassNFT : ${memberPassAddr}`);
  console.log(`  PriceConsumer : ${priceConsumerAddr}`);
  console.log(`  StakingPool   : ${stakingPoolAddr}`);
  console.log(`  MemberDAO     : ${memberDAOAddr}`);
  console.log(`\n📁 Endereços salvos em: frontend/addresses.json`);
  console.log("\n🔍 Etherscan (Sepolia):");
  Object.entries(addresses.explorer).forEach(([k, v]) => console.log(`  ${k}: ${v}`));
  console.log("");
}

main().catch((err) => {
  console.error("\n✗ Deploy falhou:", err);
  process.exitCode = 1;
});