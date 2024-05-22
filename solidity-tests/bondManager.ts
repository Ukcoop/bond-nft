import { ethers } from 'hardhat';
const { expect } = require("chai");

let bondManager;
let testingHelper;
let WBTC;

const WBTCAddress = '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f';
const USDCAddress = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';

const abi = [
  'function approve(address spender, uint256 value) public returns (bool)'
];

it('should deploy bond mamager', async() => {
  bondManager = await ethers.deployContract('BondManager');
});

it('should deploy testing helper', async() => {
  testingHelper = await ethers.deployContract('TestingHelper');
});

it('should connect to the WBTC contract', async() => {
  WBTC = new ethers.Contract(WBTCAddress, abi, ethers.provider);
});

it('should allow the user to post a bond with ETH as collatral', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let res = await bondManager.connect(addr).postETHToTokenbondRequest(WBTCAddress, BigInt(1 * 10 ** 17), 168, 5, {value: BigInt(1 * 10 ** 18)});
  expect(res);
});

it('should allow the user to  post a bond with WBTC as collatral', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  await(await testingHelper.connect(addr).swapETHforToken(WBTCAddress, {value: BigInt(1 * 10 ** 18)})).wait();
  let amount = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let res = await(await WBTC.connect(addr).approve(bondManager.target, amount)).wait();
  res = await bondManager.connect(addr).postTokenToTokenbondRequest(WBTCAddress, amount, USDCAddress, BigInt(1000 * 10 ** 6), 168, 5);
  expect(res);
});
