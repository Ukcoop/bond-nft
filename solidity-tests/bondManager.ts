import { ethers } from 'hardhat';
const { expect } = require("chai");

// these can have interfaces
let bondManager: any;
let testingHelper: any;
let WBTC: any;
let USDC: any;

const WETHAddress = '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1';
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

it('should connect to the USDC contract', async() => {
  USDC = new ethers.Contract(USDCAddress, abi, ethers.provider);
});

it('should allow the user to post a bond with ETH as collatral', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let res = await bondManager.connect(addr).postETHToTokenbondRequest(WBTCAddress, BigInt(1 * 10 ** 7), 168, 5, {value: BigInt(1 * 10 ** 18)});
  expect(res);
});

it('should allow the user to post another ETH bond request', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let res = await bondManager.connect(addr).postETHToTokenbondRequest(WBTCAddress, BigInt(1 * 10 ** 7), 168, 5, {value: BigInt(1 * 10 ** 18)});
  expect(res);
});


it('should allow another user to supply their WBTC for the loan', async() => {
  let other;
  [, other] = await ethers.getSigners();
  let res1 = await bondManager.getBondRequests();
  let input = await testingHelper.getAmountIn(WETHAddress, WBTCAddress, res1[0][1][3] + (res1[0][1][3] / BigInt(10)));
  await(await testingHelper.connect(other).swapETHforToken(WBTCAddress, {value: input})).wait();
  let amount = await testingHelper.connect(other).getTokenBalance(WBTCAddress);
  let res = await(await WBTC.connect(other).approve(bondManager.target, amount)).wait();
  res = await bondManager.connect(other).lendToETHBorrower([...res1[0][1]]);
});

it('should allow the user to cancel a ETH bond request', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let res1 = await bondManager.getBondRequests();
  let res = await bondManager.connect(addr).cancelETHToTokenBondRequest([...res1[0][0]]);
  expect(res);
});

it('should allow the user to post a bond with WBTC as collatral', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  await(await testingHelper.connect(addr).swapETHforToken(WBTCAddress, {value: BigInt(1 * 10 ** 18)})).wait();
  let amount = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let res = await(await WBTC.connect(addr).approve(bondManager.target, amount)).wait();
  res = await bondManager.connect(addr).postTokenToTokenbondRequest(WBTCAddress, amount, USDCAddress, BigInt(1000 * 10 ** 6), 168, 5);
  expect(res);
});

it('should allow the user to post another Token bond request', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  await(await testingHelper.connect(addr).swapETHforToken(WBTCAddress, {value: BigInt(1 * 10 ** 18)})).wait();
  let amount = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let res = await(await WBTC.connect(addr).approve(bondManager.target, amount)).wait();
  res = await bondManager.connect(addr).postTokenToTokenbondRequest(WBTCAddress, amount, USDCAddress, BigInt(1000 * 10 ** 6), 168, 5);
  expect(res);
});

it('should allow another user to supply their USDC for the loan', async() => {
  let other;
  [, other] = await ethers.getSigners();
  let res1 = await bondManager.getBondRequests();
  let input = await testingHelper.getAmountIn(WETHAddress, USDCAddress, res1[1][1][4] + (res1[1][1][4] / BigInt(10)));
  await(await testingHelper.connect(other).swapETHforToken(USDCAddress, {value: input})).wait();
  let amount = await testingHelper.connect(other).getTokenBalance(USDCAddress);
  let res = await(await USDC.connect(other).approve(bondManager.target, amount)).wait();
  res = await bondManager.connect(other).lendToTokenBorrower([...res1[1][1]]);
});

it('should allow the user to cancel a Token bond request', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let res1 = await bondManager.getBondRequests();
  let res = await bondManager.connect(addr).cancelTokenToTokenBondRequest([...res1[1][0]]);
  expect(res);
});
