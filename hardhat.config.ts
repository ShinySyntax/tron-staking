import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require('dotenv').config();


const config: HardhatUserConfig = {
  // defaultNetwork: "sepolia",
  networks: {
    hardhat: {
    },
    mainnet: {
      url: "https://mainnet.infura.io/v3/9262ebaabe4842b392b39b54cda79f9b",
      accounts: [process.env.PRIVATE_KEY]
    },
    mumbai: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/Jx0noqyrJNYrfVoBk97uQFJ_OlgL2juD",
      accounts: [process.env.PRIVATE_KEY]
    },
    goerli: {
      url: "https://goerli.infura.io/v3/7b469035cb45417084f3f4433f10a8ae",
      accounts: [process.env.PRIVATE_KEY]
    },
    sepolia: {
      url: "https://sepolia.infura.io/v3/9262ebaabe4842b392b39b54cda79f9b",
      accounts: [process.env.PRIVATE_KEY]
    },
    base: {
      url: "https://mainnet.base.org",
      accounts: [process.env.PRIVATE_KEY]
    },
  },
  solidity: {
    version: "0.8.20",
    settings: {
      
        optimizer: {
          enabled: true,
          runs: 1000,
        },
        // viaIR: true,
      
    },
    
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.SEPOLIA_API_KEY,
    },
  }
  
}

export default config;




