import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.25",
  defaultNetwork: "localhost",
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
