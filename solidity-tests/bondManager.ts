import { ethers } from 'hardhat';
const { expect } = require("chai");

it('should deploy', async() => {
  const bondManager = await ethers.deployContract('BondManager');
});
