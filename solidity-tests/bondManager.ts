import { ethers } from 'hardhat';
const { expect } = require('chai');

import ABI from '../constants/abi';

// these can have interfaces
let bondManager: any;
let tokenBank: any;
let testingHelper: any;
let WBTC: any;
let USDC: any;

const WETHAddress = '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1';
const WBTCAddress = '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f';
const USDCAddress = '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8';

let ETHToTokenBorrowed = 0;
let TokenToETHBorrowed = 0;
let TokenToTokenBorrowed = 0;

// initialization
it('should deploy bond mamager', async() => {
  tokenBank = await ethers.deployContract('TokenBank');
  let priceOracleManager = await ethers.deployContract('PriceOracleManager');
  let requestManager = await ethers.deployContract('RequestManager', [tokenBank.target, priceOracleManager.target]);
  let bondContractsManager = await ethers.deployContract('BondContractsManager', [tokenBank.target, priceOracleManager.target, requestManager.target]); 
  bondManager = await ethers.deployContract('BondManager', [requestManager.target, bondContractsManager.target, true]);
  
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
  
  let amountA = await ethers.provider.getBalance(addr.address);
  ETHToTokenBorrowed = BigInt(1 * 10 ** 7);
  let res = await(await bondManager.connect(addr).postETHToTokenbondRequest(WBTCAddress, 80, 168, 5, {value: BigInt(1 * 10 ** 18)})).wait();
  let amountB = await ethers.provider.getBalance(addr.address);
  
  expect((amountB - amountA) == BigInt(1 * 10 ** 18));
  expect(res);
});

it('should allow the user to post another ETH to token bond request with WBTC as the borrowed token', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  
  let amountA = await ethers.provider.getBalance(addr.address);
  ETHToTokenBorrowed = BigInt(1 * 10 ** 7);
  let res = await(await bondManager.connect(addr).postETHToTokenbondRequest(WBTCAddress, 80, 168, 5, {value: BigInt(1 * 10 ** 18)})).wait();
  let amountB = await ethers.provider.getBalance(addr.address);
  
  expect((amountB - amountA) == BigInt(1 * 10 ** 18));
  expect(res);
});

it('should allow another user to supply their WBTC for the loan', async() => {
  let other;
  [, other] = await ethers.getSigners();
  
  let res1 = await bondManager.getBondRequests();
  let amountRequired = await bondManager.getRequiredAmountForRequest([...res1[1]]); 
  // tests that use the testingHelper will fail if it's not working properly so its ok to not check the change in the balance
  let input = await testingHelper.getAmountIn(WETHAddress, WBTCAddress, amountRequired + (amountRequired / BigInt(10)));
  await(await testingHelper.connect(other).swapETHforToken(WBTCAddress, {value: input})).wait();
  
  let amountA = await testingHelper.connect(other).getTokenBalance(WBTCAddress);
  let bondContractsManagerAddress = await bondManager.getBondContractsManagerAddress();
  let res = await(await WBTC.connect(other).approve(tokenBank.target, amountRequired)).wait();
  res = await(await tokenBank.connect(other).giveAddressAccessToToken(WBTCAddress, bondContractsManagerAddress, amountRequired)).wait();
  res = await(await bondManager.connect(other).lendToTokenBorrower([...res1[1]])).wait();
  let amountB = await testingHelper.connect(other).getTokenBalance(WBTCAddress);
  
  expect((amountB - amountA) == ETHToTokenBorrowed);
  expect(res);
});

it('should allow the user to cancel an ETH collatralized bond request', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  
  let res1 = await bondManager.getBondRequests();
  
  let amountA = await ethers.provider.getBalance(addr.address);
  let res = await(await bondManager.connect(addr).cancelETHCollatralizedBondRequest([...res1[0]])).wait();
  let amountB = await ethers.provider.getBalance(addr.address);
  
  expect((amountB - amountA) == BigInt(1 * 10 ** 18));
  expect(res);
});

// these tests are testing functionality that is identical to ETH to token and token to token bonds
it('should allow the borrower to withdraw some borrowed tokens', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  
  let address = await bondManager.connect(addr).getAddressOfBorrowerContract(addr.address);
  let borrower = new ethers.Contract(address, ABI.borrower, ethers.provider);
  
  let amountA = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let res = await(await borrower.connect(addr).withdrawBorrowedTokens(BigInt(10 ** 5))).wait();
  let amountB = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  
  expect((amountB - amountA) == BigInt(10 ** 5));
  expect(res);
});

it('should allow the borrower to deposit some borrowed tokens', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  
  let address = await bondManager.connect(addr).getAddressOfBorrowerContract(addr.address);
  let borrower = new ethers.Contract(address, ABI.borrower, ethers.provider);
  let res = await(await WBTC.connect(addr).approve(address, BigInt(10 ** 5))).wait();
  
  let amountA = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  res = await(await borrower.connect(addr).depositBorrowedTokens(BigInt(10 ** 5)/BigInt(2))).wait();
  let amountB = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  
  expect((amountA - amountB) == BigInt(10 ** 5)/BigInt(2));
  expect(res);
});

it('should allow the ETH to token bond to liquidate', async() => {
  let addr, other;
  [addr, other] = await ethers.getSigners();
  
  let upkeepNeeded, data, res;
  [upkeepNeeded, data] = await bondManager.checkUpkeepWithNoCallData();
  
  let amountA = await testingHelper.connect(other).getTokenBalance(WBTCAddress);
  if(upkeepNeeded) {
    res = await(await bondManager.connect(addr).performUpkeep(data)).wait();
  }
  let amountB = await testingHelper.connect(other).getTokenBalance(WBTCAddress);
  
  expect((amountB - amountA) >= ETHToTokenBorrowed);
  expect(res);
});

// testing token to ETH bonds
it('should allow the user to post a token to ETH bond request with WBTC as collatral', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  
  await(await testingHelper.connect(addr).swapETHforToken(WBTCAddress, {value: BigInt(2 * 10 ** 18)})).wait();
  
  let amountA = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let requestManagerAddress = await bondManager.connect(addr).getRequestManagerAddress();
  let res = await(await WBTC.connect(addr).approve(tokenBank.target, amountA)).wait();
  res = await(await tokenBank.connect(addr).giveAddressAccessToToken(WBTCAddress, requestManagerAddress, amountA)).wait();
  TokenToETHBorrowed = BigInt(1 * 10 ** 18); 
  res = await(await bondManager.connect(addr).postTokenToETHBondRequest(WBTCAddress, amountA, 80, 168, 5)).wait();
  let amountB = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  
  expect((amountB - amountA) == BigInt(1 * 10 ** 18)); 
  expect(res);
});

it('should allow another user to supply their ETH for the loan', async() => {
  let other;
  [, other] = await ethers.getSigners();
  
  let res1 = await bondManager.getBondRequests();
  let amountRequired = await bondManager.getRequiredAmountForRequest([...res1[0]]); 
  
  let amountA = await ethers.provider.getBalance(other.address);  
  let res = await(await bondManager.connect(other).lendToETHBorrower([...res1[0]], {value: amountRequired + (amountRequired / BigInt(10))})).wait();
  let amountB = await ethers.provider.getBalance(other.address);
  
  expect((amountB - amountA) == TokenToETHBorrowed);
  expect(res);
});

it('should allow the borrower to withdraw some ETH', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  
  let address = await bondManager.connect(addr).getAddressOfBorrowerContract(addr.address);
  let borrower = new ethers.Contract(address, ABI.borrower, ethers.provider);
  
  let amountA = await ethers.provider.getBalance(addr.address);
  let res = await(await borrower.connect(addr).withdrawBorrowedETH(BigInt(1 * 10 ** 18))).wait();
  let amountB = await ethers.provider.getBalance(addr.address);
  
  expect((amountB - amountA) == BigInt(1 * 10 ** 18));
  expect(res);
});

it('should allow the borrower to deposit some ETH', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  
  let address = await bondManager.connect(addr).getAddressOfBorrowerContract(addr.address);
  let borrower = new ethers.Contract(address, ABI.borrower, ethers.provider);
  
  let amountA = await ethers.provider.getBalance(addr.address);
  let res = await(await borrower.connect(addr).depositBorrowedETH({value: BigInt(5 * 10 ** 17)})).wait();
  let amountB = await ethers.provider.getBalance(addr.address);
  
  expect((amountA - amountB) == BigInt(5 * 10 ** 17));
  expect(res);
});

it('should allow the token to ETH bond to liquidate', async() => {
  let addr, other;
  [addr, other] = await ethers.getSigners();
  
  let upkeepNeeded, data, res;
  [upkeepNeeded, data] = await bondManager.checkUpkeepWithNoCallData();
  
  let amountA = await ethers.provider.getBalance(other.address);// change this if it conflicts
  if (upkeepNeeded) {
    res = await(await bondManager.connect(addr).performUpkeep(data)).wait();
  }
  let amountB = await ethers.provider.getBalance(other.address);
  
  expect((amountB - amountA) >= TokenToETHBorrowed);
  expect(res);
});


// testing token to token bonds
it('should allow the user to post a token to token bond request with WBTC as collatral and USDC as the borrowed token', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  
  await(await testingHelper.connect(addr).swapETHforToken(WBTCAddress, {value: BigInt(1 * 10 ** 18)})).wait();
  
  let amountA = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let requestManagerAddress = await bondManager.connect(addr).getRequestManagerAddress();
  let res = await(await WBTC.connect(addr).approve(tokenBank.target, amountA)).wait();
  res = await(await tokenBank.connect(addr).giveAddressAccessToToken(WBTCAddress, requestManagerAddress, amountA)).wait();
  TokenToTokenBorrowed = amountA; 
  res = await(await bondManager.connect(addr).postTokenToTokenbondRequest(WBTCAddress, amountA, USDCAddress, 80, 168, 5)).wait();
  let amountB = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  
  expect(amountB <= amountA / BigInt(10));
  expect(res);
});

it('should allow the user to post another token to token bond request with WBTC as collatral and USDC as the borrowed token', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  
  await(await testingHelper.connect(addr).swapETHforToken(WBTCAddress, {value: BigInt(1 * 10 ** 18)})).wait();
  
  let amountA = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let requestManagerAddress = await bondManager.connect(addr).getRequestManagerAddress();
  let res = await(await WBTC.connect(addr).approve(tokenBank.target, amountA)).wait();
  res = await(await tokenBank.connect(addr).giveAddressAccessToToken(WBTCAddress, requestManagerAddress, amountA)).wait();
  TokenToTokenBorrowed = amountA; 
  res = await(await bondManager.connect(addr).postTokenToTokenbondRequest(WBTCAddress, amountA, USDCAddress, 80, 168, 5)).wait();
  let amountB = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  
  expect(amountB <= amountA / BigInt(10));
  expect(res);
});

it('should allow another user to supply their USDC for the loan', async() => {
  let other;
  [, other] = await ethers.getSigners();
  
  let res1 = await bondManager.getBondRequests();
  let amountRequired = await bondManager.getRequiredAmountForRequest([...res1[1]]);
  let input = await testingHelper.getAmountIn(WETHAddress, USDCAddress, amountRequired);
  await(await testingHelper.connect(other).swapETHforToken(USDCAddress, {value: input})).wait();
  
  let amountA = await testingHelper.connect(other).getTokenBalance(USDCAddress);
  let bondContractsManagerAddress = await bondManager.getBondContractsManagerAddress();
  let res = await(await USDC.connect(other).approve(tokenBank.target, amountA)).wait();
  res = await(await tokenBank.connect(other).giveAddressAccessToToken(USDCAddress, bondContractsManagerAddress, amountA)).wait();
  res = await(await bondManager.connect(other).lendToTokenBorrower([...res1[1]])).wait();
  let amountB = await testingHelper.connect(other).getTokenBalance(USDCAddress);
  
  expect((amountB - amountA) >= TokenToTokenBorrowed);
  expect(res);
});

it('should allow the user to cancel a token collatralized bond request', async() => {
  let addr;
  [addr] = await ethers.getSigners();
  
  let res1 = await bondManager.getBondRequests();
  
  let amountA = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  let res = await(await bondManager.connect(addr).cancelTokenCollatralizedBondRequest([...res1[0]])).wait();
  let amountB = await testingHelper.connect(addr).getTokenBalance(WBTCAddress);
  
  expect(amountB > amountA);
  expect(res);
});

it('should allow the token to token bond to liquidate', async() => {
  let addr, other;
  [addr, other] = await ethers.getSigners();
  
  let upkeepNeeded, data, res;
  [upkeepNeeded, data] = await bondManager.checkUpkeepWithNoCallData();
  
  let amountA = await testingHelper.connect(other).getTokenBalance(USDCAddress);
  if(upkeepNeeded) {
    res = await(await bondManager.connect(addr).performUpkeep(data)).wait();
  }
  let amountB = await testingHelper.connect(other).getTokenBalance(USDCAddress);
  
  expect((amountB - amountA) >= TokenToTokenBorrowed);
  expect(res);
});
