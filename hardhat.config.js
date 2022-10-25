require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require('@nomiclabs/hardhat-etherscan');
module.exports = {
  // solidity: "0.8.0",
  solidity: {
    compilers: [
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2000,
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
        version: "0.8.1",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2000,
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
        version: "0.8.2",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2000,
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
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2000,
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
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2000,
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
        version: "0.8.14",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2000,
            details: {
              yul: true,
              yulDetails: {
                stackAllocation: true,
                optimizerSteps: "dhfoDgvulfnTUtnIf"
              }
            }
          }
        },
      }
    ]
  },
  paths: {
    artifacts: './src/artifacts',
  },
  networks: {
    hardhat: {
      chainId: 31337
    },
    goerli: {
      gas: 2100000,
      gasPrice: 8000000000,
      url: 'https://eth-goerli.g.alchemy.com/v2/km2X06Cwy7YMKaF3VVZMHrBzK2d14ImN',
      accounts: ['ec23cd38a238a167851de39fcb64a0f6a392f3bc0c0b2da4db92393e6ec97fe6']
    },
    mumbai: {
      url: 'https://polygon-mumbai.g.alchemy.com/v2/GxYJshazn6irvMi0_BX7LXp0sUw26Nr_',
      accounts: ['45afbc2a74a48ee03ab4f31d89503da93b14b3acb38f0f38ba7afd27a22df90e']
    }
  },
  etherscan: {
    apiKey: 'FDF2MCVJIBAXZU492NY9PP1M1NIJ8ZG77K'    
  }
};
