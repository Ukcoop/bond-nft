// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

import '../tokenBank.sol';
import '../priceOracleManager.sol';
import '../shared.sol';
import '../borrowerNFT.sol';
import '../lenderNFT.sol';
import './requestManager.sol';

contract BondContractsManager is HandlesETH, ReentrancyGuard {
  mapping(address => bool) lenderCanBurn;
  LenderNFTManager immutable lenderNFTManager;
  BorrowerNFTManager immutable borrowerNFTManager;
  uintPair[] bondPairs;
  TokenBank immutable tokenBank;
  PriceOracleManager immutable priceOracleManager; 
  RequestManager immutable requestManager;
  address bondManagerAddress;
  address immutable deployer;
  
  constructor(address _tokenBank, address _priceOracleManager, address _requestManager) {
    lenderNFTManager = new LenderNFTManager();
    borrowerNFTManager = new BorrowerNFTManager();
    tokenBank = TokenBank(_tokenBank);
    requestManager = RequestManager(_requestManager);
    priceOracleManager = PriceOracleManager(_priceOracleManager);
    deployer = msg.sender;
    bondManagerAddress == address(0);
  }

  function setAddress(address bondManager) public {
    require(msg.sender == deployer, 'you are not authorized to do this action');
    require(bondManager != address(0), 'bondManager address can not be address(0)');
    require(bondManagerAddress == address(0), 'address allready set');
    bondManagerAddress = bondManager;
  }

  function getBondPairs() public view returns(uintPair[] memory) {
    require(msg.sender == bondManagerAddress, 'you are not authorized to do this action');
    return bondPairs;
  }

  // slither-disable-start costly-loop
  function deleteBondPair(uint borrowerId, uint lenderId) internal {
    uint index = 0;
    uint len = bondPairs.length;
    for(uint i = 0; i < len; i++) {
      if(bondPairs[i].borrowerId == borrowerId && bondPairs[i].lenderId == lenderId) {
        index = i;
        break;
      }
    }

    if(index >= len) {
      bondPairs.pop();
      return;
    }

    for(uint i = index; i < len - 1; i++) {
      bondPairs[i] = bondPairs[i + 1];
    }

    bondPairs.pop();
  }
  // slither-disable-end costly-loop
  
  function liquidate(uint borrowerId, uint lenderId) public {
    require(msg.sender == bondManagerAddress, 'you are not authorized to do this action');
    deleteBondPair(borrowerId, lenderId);
    lenderCanBurn[lenderNFTManager.getContractAddress(lenderId)] = true;
    Borrower borrower = Borrower(borrowerNFTManager.getContractAddress(borrowerId));
    Lender lender = Lender(lenderNFTManager.getContractAddress(lenderId));
    getDataResponse memory res = lender.getData();
    require(res.borrowerId == borrowerId, 'the lender does not have this address as the borrower');
    borrower.liquidate(address(lender));
    lender.liquidate();
    borrowerNFTManager.burnBorrowerContract(borrowerId); 
  }

  function burnFromLender(uint lenderId) public {
    require(lenderCanBurn[msg.sender], 'lender can not burn');
    lenderNFTManager.burnLenderContract(lenderId); 
  }

  function getBorrowersIds(address borrower) public view returns (uint[] memory) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    return borrowerNFTManager.getIds(borrower);
  }

  function getLendersIds(address lender) public view returns (uint[] memory) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    return lenderNFTManager.getIds(lender);
  }

  function getAddressOfBorrowerContract(uint id) public view returns (address) {
    return borrowerNFTManager.getContractAddress(id);
  }

  function getAddressOfLenderContract(uint id) public view returns (address) {
    return lenderNFTManager.getContractAddress(id);
  }

  // slither-disable-start reentrancy-benign
  function lendToTokenBorrower(address lender, bondRequest memory request) public nonReentrant {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    
    uint borrowedAmount = (priceOracleManager.getPrice(request.collatralAmount, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, request.borrowingtoken) * request.borrowingPercentage) / 100;
    uint lenderId = lenderNFTManager.getNextId();
    uint borrowerId = borrowerNFTManager.getNextId();
    bondPairs.push(uintPair(borrowerId, lenderId));

    lenderNFTManager.createLenderContract(address(borrowerNFTManager), address(priceOracleManager), lender, borrowerId, lenderId, borrowedAmount, request);
    borrowerNFTManager.createBorrowerCotract(address(lenderNFTManager), address(priceOracleManager), borrowerId, lenderId, borrowedAmount, request); 

    requestManager.deleteBondRequest(uint(index));

    address lenderContractAddress = lenderNFTManager.getContractAddress(lenderId);
    address borrowerContractAddress = borrowerNFTManager.getContractAddress(borrowerId);

    bool status = tokenBank.spendAllowedTokens(request.borrowingtoken, lender, borrowerContractAddress, borrowedAmount); 
    require(status, 'transferFrom failed');
    if(request.collatralToken == address(1)) {
      requestManager.sendFromBondContractsManager(payable(lenderContractAddress), request.collatralAmount);
    } else {
      status = requestManager.sendTokenFromBondContractsManager(request.collatralToken, request.borrower, lenderContractAddress, request.collatralAmount);
      require(status, 'transfer failed');
    }
  }

  function lendToETHBorrower(address lender, bondRequest memory request) public payable nonReentrant {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');

    uint borrowedAmount = (priceOracleManager.getPrice(request.collatralAmount, request.collatralToken, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1) * request.borrowingPercentage) / 100; 

    uint lenderId = lenderNFTManager.getNextId();
    uint borrowerId = borrowerNFTManager.getNextId();
    bondPairs.push(uintPair(borrowerId, lenderId));

    lenderNFTManager.createLenderContract(address(borrowerNFTManager), address(priceOracleManager), lender, borrowerId, lenderId, borrowedAmount, request);
    borrowerNFTManager.createBorrowerCotract(address(lenderNFTManager), address(priceOracleManager), borrowerId, lenderId, borrowedAmount, request);

    requestManager.deleteBondRequest(uint(index));

    address lenderContractAddress = lenderNFTManager.getContractAddress(lenderId);
    address borrowerContractAddress = borrowerNFTManager.getContractAddress(borrowerId);

    sendViaCall(payable(borrowerContractAddress), borrowedAmount);
    bool status = requestManager.sendTokenFromBondContractsManager(request.collatralToken, request.borrower, lenderContractAddress, request.collatralAmount);
    require(status, 'transfer failed');
  }
  // slither-disable-end reentrancy-benign
}
