import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "localhost",
  allowUnlimitedContractSize: true,
  networks: {
    hardhat: {
      forking: {
        url: "https://arb1.arbitrum.io/rpc",
      }
    },
    localhost: {
      url: "http://127.0.0.1:8545"
    }
  },
  paths: {
    tests:'./solidity-tests'
  }
};

export default config;
