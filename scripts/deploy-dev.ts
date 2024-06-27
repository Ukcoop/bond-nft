import { ethers } from "hardhat";
const fs = require('fs');

async function writeJSON(path: string, data: Object) {
  await fs.writeFileSync(path, JSON.stringify(data));
  return data;
}

async function main() {
  let tokenBank  = await ethers.deployContract('TokenBank');
  let testingHelper = await ethers.deployContract('TestingHelper');
  let priceOracleManager = await ethers.deployContract('PriceOracleManager');
  let requestManager = await ethers.deployContract('RequestManager', [tokenBank.target, priceOracleManager.target]);
  let bondContractsManager = await ethers.deployContract('BondContractsManager', [tokenBank.target, priceOracleManager.target, testingHelper.target, requestManager.target]);
  let bondManager = await ethers.deployContract('BondManager', [requestManager.target, bondContractsManager.target, tokenBank.target, true]);
  let addr;
  [addr] = await ethers.getSigners();
  await requestManager.connect(addr).setAddress(bondManager.target, bondContractsManager.target);
  await bondContractsManager.connect(addr).setAddress(bondManager.target);

  let json = {
    bondManager: bondManager.target
  }

  await writeJSON('constants/deploy-dev.json', json);
  console.log(`bond nft deployed on localhost: ${bondManager.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
