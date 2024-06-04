import { ethers } from 'hardhat';
const { expect } = require('chai');

import ABI from '../constants/abi';

// these can have interfaces
let bondManager: any;
let testingHelper: any;
let WBTC: any;
let USDC: any;

const WETHAddress = '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1';
const WBTCAddress = '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f';
const USDCAddress = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';


// initialization
it('should deploy bond mamager', async() => {
  //let tokenManager = await ethers.deployContract('TokenManager');
  let requestManager = await ethers.deployContract('RequestManager');
  let bondContractsManager = await ethers.deployContract('BondContractsManager', [requestManager.target]); 
  bondManager = await ethers.deployContract('BondManager', [requestManager.target, bondContractsManager.target]);
  let addr;
  [addr] = await ethers.getSigners();
  await requestManager.connect(addr).setAddresses(bondManager.target, bondContractsManager.target);
  await bondContractsManager.connect(addr).setAddress(bondManager.target);
});

it('should deploy testing helper', async() => {
  testingHelper = await ethers.deployContract('TestingHelper');
});

it('should connect to the WBTC contract', async() => {
  WBTC = new ethers.Contract(WBTCAddress, ABI.token, ethers.provider);
});

it('should connect to the USDC contract', async() => {
  USDC = new ethers.Contract(USDCAddress, ABI.token, ethers.provider);
});

// testing ETH to token bonds
it('should allow the user to post a ETH to token bond request with WBTC as the borrowed token', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let res = await bondManager.connect(addr).postETHToTokenbondRequest(WBTCAddress, BigInt(1 * 10 ** 7), 168, 5, {value: BigInt(1 * 10 ** 18)});
  expect(res);
});

it('should allow the user to post another ETH to token bond request with WBTC as the borrowed token', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let res = await bondManager.connect(addr).postETHToTokenbondRequest(WBTCAddress, BigInt(1 * 10 ** 7), 168, 5, {value: BigInt(1 * 10 ** 18)});
  expect(res);
});

it('should allow another user to supply their WBTC for the loan', async() => {
  let other;
  [, other] = await ethers.getSigners();
  let res1 = await bondManager.getBondRequests();
  console.log('action 1');
  let input = await testingHelper.getAmountIn(WETHAddress, WBTCAddress, res1[1][4] + (res1[1][4] / BigInt(10)));
  await(await testingHelper.connect(other).swapETHforToken(WBTCAddress, {value: input})).wait();
  let amount = await testingHelper.connect(other).getTokenBalance(WBTCAddress);
  let bondContractsManagerAddress = await bondManager.getBondContractsManagerAddress();
  console.log('action 2');
  let res = await(await WBTC.connect(other).approve(bondContractsManagerAddress, amount)).wait();
  res = await bondManager.connect(other).lendToETHToTokenBorrower([...res1[1]]);
  console.log('action 3');
});

it('should allow the user to cancel a ETH bond request', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let res1 = await bondManager.getBondRequests();
  let res = await bondManager.connect(addr).cancelETHToTokenBondRequest([...res1[0]]);
  expect(res);
});

// these tests are testing functionality that is identical to ETH to token and token to token bonds
it('should allow the borrower to withdraw some borrowed tokens', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let address = await bondManager.connect(addr).getAddressOfBorrowerContract(addr.address);
  let borrower = new ethers.Contract(address, ABI.borrower, ethers.provider);
  let res = borrower.connect(addr).withdrawBorrowedTokens(BigInt(10 ** 5));
});

it('should allow the borrower to deposit some borrowed tokens', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let address = await bondManager.connect(addr).getAddressOfBorrowerContract(addr.address);
  let borrower = new ethers.Contract(address, ABI.borrower, ethers.provider);
  let res = await(await WBTC.connect(addr).approve(address, BigInt(10 ** 5))).wait();
  res = borrower.connect(addr).depositBorrowedTokens(BigInt(10 ** 5));
});

it('should allow the borrower and lender contract to liquidate', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let address = await bondManager.connect(addr).getAddressOfBorrowerContract(addr.address);
  let borrower = new ethers.Contract(address, ABI.borrower, ethers.provider);
  let res = borrower.connect(addr).liquidate();
});

// testing token to ETH bonds
it('should allow the user to post a token to ETH bond request with WBTC as collatral', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  await(await testingHelper.connect(addr).swapETHforToken(WBTCAddress, {value: BigInt(2 * 10 ** 18)})).wait();
  let amount = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let requestManagerAddress = await bondManager.connect(addr).getRequestManagerAddress();
  let res = await(await WBTC.connect(addr).approve(requestManagerAddress, amount)).wait();
  res = await bondManager.connect(addr).postTokenToETHBondRequest(WBTCAddress, amount, BigInt(1 * 10 ** 18), 168, 5);
  expect(res);
});

it('should allow another user to supply their ETH for the loan', async() => {
  let other;
  [, other] = await ethers.getSigners();
  let res1 = await bondManager.getBondRequests();
  let res = await bondManager.connect(other).lendToTokenToETHBorrower([...res1[0]], {value: res1[0][4]}); 
});

it('should allow the borrower to withdraw some ETH', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let address = await bondManager.connect(addr).getAddressOfBorrowerContract(addr.address);
  let borrower = new ethers.Contract(address, ABI.borrower, ethers.provider);
  let res = borrower.connect(addr).withdrawBorrowedETH(BigInt(1 * 10 ** 18));
});

it('should allow the borrower to deposit some ETH', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let address = await bondManager.connect(addr).getAddressOfBorrowerContract(addr.address);
  let borrower = new ethers.Contract(address, ABI.borrower, ethers.provider);
  let res = borrower.connect(addr).depositBorrowedETH({value: BigInt(1 * 10 ** 18)});
});

it('should allow the borrower and lender contract to liquidate', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let address = await bondManager.connect(addr).getAddressOfBorrowerContract(addr.address);
  let borrower = new ethers.Contract(address, ABI.borrower, ethers.provider);
  let res = borrower.connect(addr).liquidate();
});

// testing token to token bonds
it('should allow the user to post a token to token bond request with WBTC as collatral and USDC as the borrowed token', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  await(await testingHelper.connect(addr).swapETHforToken(WBTCAddress, {value: BigInt(1 * 10 ** 18)})).wait();
  let amount = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let requestManagerAddress = await bondManager.connect(addr).getRequestManagerAddress();
  let res = await(await WBTC.connect(addr).approve(requestManagerAddress, amount)).wait();
  res = await bondManager.connect(addr).postTokenToTokenbondRequest(WBTCAddress, amount, USDCAddress, BigInt(1000 * 10 ** 6), 168, 5);
  expect(res);
});

it('should allow the user to post another token to token bond request with WBTC as collatral and USDC as the borrowed token', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  await(await testingHelper.connect(addr).swapETHforToken(WBTCAddress, {value: BigInt(1 * 10 ** 18)})).wait();
  let amount = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let requestManagerAddress = await bondManager.connect(addr).getRequestManagerAddress();
  let res = await(await WBTC.connect(addr).approve(requestManagerAddress, amount)).wait();
  res = await bondManager.connect(addr).postTokenToTokenbondRequest(WBTCAddress, amount, USDCAddress, BigInt(1000 * 10 ** 6), 168, 5);
  expect(res);
});

it('should allow another user to supply their USDC for the loan', async() => {
  let other;
  [, other] = await ethers.getSigners();
  let res1 = await bondManager.getBondRequests();
  let input = await testingHelper.getAmountIn(WETHAddress, USDCAddress, res1[1][4] + (res1[1][4] / BigInt(10)));
  await(await testingHelper.connect(other).swapETHforToken(USDCAddress, {value: input})).wait();
  let amount = await testingHelper.connect(other).getTokenBalance(USDCAddress);
  let bondContractsManagerAddress = await bondManager.getBondContractsManagerAddress();
  let res = await(await USDC.connect(other).approve(bondContractsManagerAddress, amount)).wait();
  res = await bondManager.connect(other).lendToTokenToTokenBorrower([...res1[1]]);
});

it('should allow the user to cancel a token to token bond request', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  let res1 = await bondManager.getBondRequests();
  let res = await bondManager.connect(addr).cancelTokenToTokenBondRequest([...res1[0]]);
  expect(res);
});
