// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '../tokenBank.sol';
import '../priceOracleManager.sol';
import '../shared.sol';

//AUDIT: can be optimized

contract RequestManager is HandlesETH {
  address[] public whitelistedTokens;
  bondRequest[] internal bondRequests;
  TokenBank internal immutable tokenBank;
  PriceOracleManager internal immutable priceOracleManager;  
  address internal immutable deployer;
  address internal bondManagerAddress;
  address internal bondContractsManagerAddress;
  
  constructor(address _tokenBank, address _priceOracleManager) {
    whitelistedTokens = new address[](8);
    whitelistedTokens[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // wrapped ETH
    whitelistedTokens[1] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT
    whitelistedTokens[2] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // bridged USDC
    whitelistedTokens[3] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC
    whitelistedTokens[4] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; // wrapped BTC
    whitelistedTokens[5] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI
    whitelistedTokens[6] = 0x680447595e8b7b3Aa1B43beB9f6098C79ac2Ab3f; // USDD
    whitelistedTokens[7] = 0x4D15a3A2286D883AF0AA1B3f21367843FAc63E07; // TUSD

    deployer = msg.sender;
    tokenBank = TokenBank(_tokenBank);
    priceOracleManager = PriceOracleManager(_priceOracleManager);
    bondManagerAddress = address(0);
    bondContractsManagerAddress = address(0);
  }

  function isWhitelistedToken(address token) public view returns (bool) {
    uint len = whitelistedTokens.length; 
    for (uint i; i < len; i++) {
      if (token == whitelistedTokens[i]) {
        return true;
      }
    }
    return false;
  }

  function setAddress(address bondManager, address bondContractsManager) public {
    require(bondManager != address(0), 'bondManager address can not be address(0)');
    require(bondContractsManager != address(0), 'bondContractsManager address cant be address(0)');
    require(msg.sender == deployer, 'only the deployer can do this action');
    bondManagerAddress = bondManager;
    bondContractsManagerAddress = bondContractsManager;
  }

  function sendFromBondContractsManager(address payable to, uint value) public payable {
    require(msg.sender == bondContractsManagerAddress, 'you are not authorized to do this action');
    sendViaCall(to, value);
  }

  function sendTokenFromBondContractsManager(address token, address borrower, address to, uint value) public returns (bool status) {
    require(msg.sender == bondContractsManagerAddress, 'you are not authorized to do this action');
    status = tokenBank.spendAllowedTokens(token, borrower, to, value);
  }

  function deleteBondRequest(uint index) public {
    require(msg.sender == bondManagerAddress || msg.sender == bondContractsManagerAddress, 'you are not authorized to do this action');
    if (index >= bondRequests.length) {
      bondRequests.pop();
      return;
    }
    
    uint len = bondRequests.length; 
    for (uint i = index; i < len - 1; i++) {
      bondRequests[i] = bondRequests[i + 1];
    }
    bondRequests.pop();
  }

  function getRequiredAmountForRequest(bondRequest memory request) public view returns (uint) {
    uint percent = request.borrowingPercentage;
    uint full =  priceOracleManager.getPrice(request.collatralAmount,
                                      (request.collatralToken == address(1) ? 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 : request.collatralToken),
                                      (request.borrowingToken == address(1) ? 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 : request.borrowingToken));
    uint res = (full * percent) / 100;
    return res;
  }

  function postETHToTokenbondRequest(
    address borrower,
    address borrowingToken,
    uint32 borrowingPercentage,
    uint32 termInHours,
    uint32 intrestYearly
  ) public payable returns (bool) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    require(borrower != address(0), 'borrowr address can not be address(0)');
    require(msg.value != 0, 'cant post a bond with no collatral');
    require(isWhitelistedToken(borrowingToken), 'this token is not whitelisted');
    require(borrowingPercentage <= 80 && borrowingPercentage >= 20, 'borrowingPercentage is not in range: (20 to 80)%');
    require(termInHours > 24, 'bond length is too short');
    require(intrestYearly > 2 && intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');

    bondRequest memory newRequest = bondRequest(
      borrower,
      address(1),
      msg.value,
      borrowingToken,
      borrowingPercentage,
      termInHours,
      intrestYearly
    );
    bondRequests.push(newRequest);
    return true;
  }

  function postTokenToETHBondRequest(
    address borrower,
    address collatralToken,
    uint collatralAmount,
    uint32 borrowingPercentage,
    uint32 termInHours,
    uint32 intrestYearly
  ) public returns (bool) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    require(borrower != address(0), 'borrowr address can not be address(0)');
    require(collatralAmount != 0, 'cant post a bond with no collatral');
    require(borrowingPercentage <= 80 && borrowingPercentage >= 20, 'borrowingPercentage is not in range: (20 to 80)%');
    require(isWhitelistedToken(collatralToken), 'this token is not whitelisted');
    require(termInHours > 24, 'bond length is too short');
    require(intrestYearly > 2 && intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');

    bondRequest memory newRequest = bondRequest(
      borrower,
      collatralToken,
      collatralAmount,
      address(1),
      borrowingPercentage,
      termInHours,
      intrestYearly
    );
    bondRequests.push(newRequest);
    uint res = tokenBank.findAllowanceEntryWithMinimumBalance(collatralToken, borrower, address(this), collatralAmount);
    res++;
    return true;
  }

  function postTokenToTokenbondRequest(
    address borrower,
    address collatralToken,
    uint collatralAmount,
    address borrowingToken,
    uint32 borrowingPercentage,
    uint32 termInHours,
    uint32 intrestYearly
  ) public returns (bool) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    require(borrower != address(0), 'borrowr address can not be address(0)');
    require(collatralAmount != 0, 'cant post a bond with no collatral');
    require(isWhitelistedToken(collatralToken), 'this token is not whitelisted');
    require(isWhitelistedToken(borrowingToken), 'this token is not whitelisted');
    require(borrowingPercentage <= 80 && borrowingPercentage >= 20, 'borrowingPercentage is not in range: (20 to 80)%');
    require(termInHours > 24, 'bond length is too short');
    require(intrestYearly > 2 && intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');

    bondRequest memory newRequest = bondRequest(
      borrower,
      collatralToken,
      collatralAmount,
      borrowingToken,
      borrowingPercentage,
      termInHours,
      intrestYearly
    );
    bondRequests.push(newRequest);
    uint res = tokenBank.findAllowanceEntryWithMinimumBalance(collatralToken, borrower, address(this), collatralAmount);
    res++; 
    return true;
  }

  function indexOfBondRequest(bondRequest memory request) public view returns (int) {
    require(msg.sender == bondManagerAddress || msg.sender == bondContractsManagerAddress, 'you are not authorized to do this action');
    uint len = bondRequests.length; 
    for (uint i = 0; i < len; i++) {
      bool isMatching = (
        (bondRequests[i].borrower == request.borrower) &&
        (bondRequests[i].collatralToken == request.collatralToken) &&
        (bondRequests[i].collatralAmount == request.collatralAmount) &&
        (bondRequests[i].borrowingToken == request.borrowingToken) &&
        (bondRequests[i].durationInHours == request.durationInHours) &&
        (bondRequests[i].intrestYearly == request.intrestYearly)
      );
      if (isMatching) {
        return int(i);
      }
    }
    return -1;
  }

  function cancelETHCollatralizedBondRequest(address borrower, bondRequest memory request) public returns (bool) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    require(bondRequests[uint(index)].borrower == borrower, 'not the borrower');
    uint amount = bondRequests[uint(index)].collatralAmount;
    deleteBondRequest(uint(index));
    sendViaCall(payable(request.borrower), amount);
    return true;
  }

  function cancelTokenCollatralizedBondRequest(address borrower, bondRequest memory request) public payable returns (bool) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    require(bondRequests[uint(index)].borrower == borrower, 'not the borrower');
    uint amount = bondRequests[uint(index)].collatralAmount;
    address token = bondRequests[uint(index)].collatralToken;
    deleteBondRequest(uint(index));
    bool status = tokenBank.spendAllowedTokens(token, request.borrower, request.borrower, amount);
    require(status, 'transfer from BondManager to msg.sender failed');
    return true;
  }

  function getBondRequests() public view returns (bondRequest[] memory) {
    return bondRequests;
  }
}
