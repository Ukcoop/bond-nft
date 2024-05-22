// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// import "hardhat/console.sol";

struct ethBondRequest {
  address borrower;
  uint256 ETHAmount;
  address token;
  uint256 tokenAmount;
  uint256 intrestYearly;
}

struct tokenBondRequest {
  address borrower;
  address collatralToken;
  uint256 collatralAmount;
  address borrowingtoken;
  uint256 borrowingAmount;
  uint256 intrestYearly;
}

contract BondManager is ReentrancyGuard {
  mapping(address => ethBondRequest) public ethBondRequests;
  mapping(address => tokenBondRequest) public tokenBondRequests;
  address[] ethBondRequestAddresses;
  address[] tokenBondRequestAddresses;

  address[] whitelistedTokens;

  constructor() {
  whitelistedTokens = new address[](9);
    whitelistedTokens[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;// wrapped ETH
    whitelistedTokens[1] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;// USDT
    whitelistedTokens[2] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;// bridged USDC
    whitelistedTokens[3] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;// USDC
    whitelistedTokens[4] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;// wrapped BTC
    whitelistedTokens[5] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;// DAI
    whitelistedTokens[6] = 0x912CE59144191C1204E64559FE8253a0e49E6548;// ARB
    whitelistedTokens[7] = 0x680447595e8b7b3Aa1B43beB9f6098C79ac2Ab3f;// USDD
    whitelistedTokens[8] = 0x4D15a3A2286D883AF0AA1B3f21367843FAc63E07;// TUSD
  }

  function isWhitelistedToken(address token) internal view returns (bool) {
    bool res = false;
    uint len = whitelistedTokens.length; 
    for(uint i = 0; i < len; i++) {
      if(token == whitelistedTokens[i]) {
        res = true;
      }
    }
    return res;
  }

  function sendViaCall(address payable to, uint value) public payable {
    require(to != payable(address(0)), 'cant send to the 0 address');
    require(value != 0, 'can not send nothing');
    (bool sent, bytes memory data) = to.call{value: value}("");
    require(sent, "Failed to send Ether");
  }
  
  function postETHToTokenbondRequest(address borrowingToken, uint borrowingAmount, uint termInHours, uint intrestYearly) public payable returns (bool) {
    require(msg.value != 0, 'cant post a bond with no collatral');
    require(isWhitelistedToken(borrowingToken), 'this token is not whitelisted');
    require(borrowingAmount != 0, 'cant borrow nothing');
    require(termInHours > 24, 'bond length is too short');
    require(intrestYearly > 2 && intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');
    
    ethBondRequest memory newRequest = ethBondRequest(msg.sender, msg.value, borrowingToken, borrowingAmount, intrestYearly);
    ethBondRequests[msg.sender] = newRequest;
    ethBondRequestAddresses.push(msg.sender);
    
    return true;
  }

  function postTokenToTokenbondRequest(address collatralToken, uint collatralAmount, address borrowingToken, uint borrowingAmount, uint termInHours, uint intrestYearly) public nonReentrant returns (bool) {
    require(collatralAmount != 0, 'cant post a bond with no collatral');
    require(isWhitelistedToken(borrowingToken), 'this token is not whitelisted');
    require(borrowingAmount != 0, 'cant borrow nothing');
    require(termInHours > 24, 'bond length is too short');
    require(intrestYearly > 2 && intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');

    IERC20 collatralTokenContract = IERC20(collatralToken);
    uint allowance = collatralTokenContract.allowance(msg.sender, address(this));
    require(allowance >= collatralAmount, 'allowance is not high ehough');

    tokenBondRequest memory newRequest = tokenBondRequest(msg.sender, collatralToken, collatralAmount, borrowingToken, borrowingAmount, intrestYearly);
    tokenBondRequests[msg.sender] = newRequest;
    tokenBondRequestAddresses.push(msg.sender);   

    bool status = collatralTokenContract.transferFrom(msg.sender, address(this), collatralAmount);
    require(status, 'transferFrom failed');
    return true;
  }

  function cancelETHToTokenBondRequest() public payable returns (bool) {
    int index = -1;
    for (int i = 0; i < int(ethBondRequestAddresses.length); i++) {
      if (ethBondRequestAddresses[uint(i)] == msg.sender) {
        index = i;
      }
    }
    require(index != -1, 'no bond request for this address');
    uint amount = ethBondRequests[msg.sender].ETHAmount;
    delete ethBondRequests[msg.sender];
    delete ethBondRequestAddresses[uint(index)];
    sendViaCall(payable(msg.sender), amount);
    return true;
  }

  function canceltokenToTokenBondRequest() public payable returns (bool) {
    int index = -1;
    for (int i = 0; i < int(tokenBondRequestAddresses.length); i++) {
      if (tokenBondRequestAddresses[uint(i)] == msg.sender) {
        index = i;
      }
    }
    require(index != -1, 'no bond request for this address');
    uint amount = tokenBondRequests[msg.sender].collatralAmount;
    address token = tokenBondRequests[msg.sender].collatralToken; 
    delete tokenBondRequests[msg.sender];
    delete tokenBondRequestAddresses[uint(index)];
    IERC20 tokenContract = IERC20(token);
    bool status = tokenContract.transfer(msg.sender, amount);
    require(status, 'tranfer from BondManager to msg.sender failed');
    return true;
  }
}
