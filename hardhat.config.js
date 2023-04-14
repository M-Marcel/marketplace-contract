require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan")
require("dotenv").config({ path: ".env" });

const GOERLI_API_KEY_URL = process.env.GOERLI_API_KEY_URL;

const SEPOLIA_API_KEY_URL = process.env.SEPOLIA_API_KEY_URL;

const PRIVATE_KEY = process.env.PRIVATE_KEY;

const API_TOKEN = process.env.ETHERSCAN_KEY;

module.exports = {
  solidity: {
    compilers: [
        {
            version: "0.8.0",
        },
        {
            version: "0.8.10",
        }
    ],
},
  networks: {
    goerli: {
      url: GOERLI_API_KEY_URL,
      accounts: [PRIVATE_KEY],
    },
    sepolia: {
      url: SEPOLIA_API_KEY_URL,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: API_TOKEN
  },
  lockGasLimit: 200000000000,
  gasPrice: 10000000000,
};