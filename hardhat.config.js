require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const PRIVATE_KEY  = process.env.PRIVATE_KEY  || "0x" + "0".repeat(64);
const SEPOLIA_RPC  = process.env.SEPOLIA_RPC  || "";
const ETHERSCAN_KEY = process.env.ETHERSCAN_KEY || "";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      evmVersion: "cancun",
      optimizer: { enabled: true, runs: 200 },
    },
  },
  networks: {
    hardhat: {
      hardfork: "cancun",
      chainId: 31337,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    sepolia: {
      url: SEPOLIA_RPC,
      accounts: [PRIVATE_KEY],
      chainId: 11155111,
      gasPrice: "auto",
    },
  },
  etherscan: {
    apiKey: { sepolia: ETHERSCAN_KEY },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  paths: {
    sources:   "./contracts",
    tests:     "./test",
    cache:     "./cache",
    artifacts: "./artifacts",
  },
};
