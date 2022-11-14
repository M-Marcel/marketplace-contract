// require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-etherscan")
// require("@openzeppelin/hardhat-upgrades");
require("hardhat-deploy")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("hardhat-contract-sizer")
require("dotenv").config()
const { ethers } = require("ethers")

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const MAINNET_RPC_URL =
  process.env.MAINNET_RPC_URL ||
  process.env.ALCHEMY_MAINNET_RPC_URL ||
  "https://eth-mainnet.alchemyapi.io/v2/your-api-key"
const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL || "https://eth-kovan.alchemyapi.io/v2/your-api-key"
const BINANCE_SMARTCHAIN_MAINNET_RPC_URL = process.env.BINANCE_SMARTCHAIN_MAINNET_RPC_URL
const BINANCE_SMARTCHAIN_TESTNET_RPC_URL = process.env.BINANCE_SMARTCHAIN_TESTNET_RPC_URL
const POLYGON_MAINNET_RPC_URL =
  process.env.POLYGON_MAINNET_RPC_URL || "https://polygon-mainnet.alchemyapi.io/v2/your-api-key"
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x"
// optional
const MNEMONIC = process.env.MNEMONIC || "your mnemonic"

// Your API key for Etherscan, obtain one at https://etherscan.io/ 
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "Your etherscan API key"
// const BSCSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "Your etherscan API key"
const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY || "Your bscscan API key"
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || "Your polygonscan API key"
const REPORT_GAS = process.env.REPORT_GAS || true

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      // // If you want to do some forking, uncomment this
      // forking: {
      //   url: MAINNET_RPC_URL
      // }
      chainId: 31337,
      blockConfirmations: 1,
      gas: 210000000,
      gasPrice: 800000000000,
      blockGasLimit: 30902728800,
      // gas: ethers.utils.parseEther("1"),
      // gasLimit: ethers.utils.parseEther("1"),
      // gasPrice: ethers.utils.parseEther("1"),
    },
    localhost: {
      chainId: 31337,
      blockConfirmations: 1,
      gas: 210000000,
      gasPrice: 800000000000,
      lockGasLimit: 30902728800,
      // gas: ethers.utils.parseEther("1"),
      // gasLimit: ethers.utils.parseEther("1"),
      // gasPrice: ethers.utils.parseEther("1"),
    },
    binanceSCTestnet: {
      url: BINANCE_SMARTCHAIN_TESTNET_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      // accounts: "9IIXU9KC848QTC4QJJEGWPGKA8QN1HU4Z7",
      //   accounts: {
      //     mnemonic: MNEMONIC,
      //   },
      saveDeployments: true,
      chainId: 97,
      blockConfirmations: 6,
    },
    goerli: {
      url: GOERLI_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      //   accounts: {
      //     mnemonic: MNEMONIC,
      //   },
      saveDeployments: true,
      chainId: 5,
      blockConfirmations: 6,
      gas: 210000000,
      gasPrice: 800000000000,
      blockGasLimit: 30902728800,
    },
    binanceSCMainnet: {
      url: BINANCE_SMARTCHAIN_MAINNET_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      //   accounts: {
      //     mnemonic: MNEMONIC,
      //   },
      saveDeployments: true,
      chainId: 56,
      blockConfirmations: 6,
    },
    mainnet: {
      url: MAINNET_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      //   accounts: {
      //     mnemonic: MNEMONIC,
      //   },
      saveDeployments: true,
      chainId: 1,
      blockConfirmations: 6,
    },
    polygon: {
      url: POLYGON_MAINNET_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      saveDeployments: true,
      chainId: 137,
      blockConfirmations: 6,
    },
  },
  etherscan: {
    // npx hardhat verify --network <NETWORK> <CONTRACT_ADDRESS> <CONSTRUCTOR_PARAMETERS>
    apiKey: {
      rinkeby: ETHERSCAN_API_KEY,
      kovan: ETHERSCAN_API_KEY,
      goerli: ETHERSCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY,
      bscTestnet: BSCSCAN_API_KEY,
    },
  },
  gasReporter: {
    enabled: REPORT_GAS,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
    // coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  contractSizer: {
    runOnCompile: false,
    only: ["Raffle"],
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
    player: {
      default: 1,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
      },
      {
        version: "0.8.7",
      },
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2000,
            // viaIR: true,
            details: {
              yul: true,
              yulDetails: {
                stackAllocation: true,
                optimizerSteps: "dhfoDgvulfnTUtnIf"
              }
            }
          }
        },

      },
      {
        version: "0.8.0",
      },
      {
        version: "0.4.24",
      },
    ],
  },
  mocha: {
    timeout: 200000, // 200 seconds max for running tests
  },
}
