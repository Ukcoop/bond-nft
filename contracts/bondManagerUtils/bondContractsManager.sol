// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '../tokenBank.sol';
import '../priceOracleManager.sol';
import '../shared.sol';
import '../borrowerNFT.sol';
import '../lenderNFT.sol';
import './requestManager.sol';

contract BondContractsManager is HandlesETH {
  mapping(address => Borrower) public borrowerContracts;
  mapping(address => Lender) public lenderContracts;
  TokenBank immutable tokenBank;
  PriceOracleManager immutable priceOracleManager; 
  RequestManager immutable requestManager;
  address immutable deployer;
  address bondManagerAddress;
  
  constructor(address _tokenBank, address _priceOracleManager, address _requestManager) {
    tokenBank = TokenBank(_tokenBank);
    requestManager = RequestManager(_requestManager);
    priceOracleManager = PriceOracleManager(_priceOracleManager);
    deployer = msg.sender;
  }
  
  //slither-disable-next-line naming-convention
  function setAddress(address _bondManagerAddress) public {
    require(_bondManagerAddress != address(0), 'bondManagerAddress can not be address(0)');
    require(msg.sender == deployer, 'only the deployer can do this action');
    require(bondManagerAddress == address(0), 'bondManagerAddress allredy initialized');
    bondManagerAddress = _bondManagerAddress;
  }
  
  // slither-disable-start reentrancy-no-eth
  function liquidate(address borrower, address lender) public {
    require(msg.sender == address(borrowerContracts[borrower]) || msg.sender == bondManagerAddress, 'you are not authorized to do this action');
    getDataResponse memory res = lenderContracts[lender].getData();
    require(res.borrower == borrower, 'the lender does not have this address as the borrower');
    borrowerContracts[borrower].liquidate(address(lenderContracts[lender]));
    lenderContracts[lender].liquidate();
    delete borrowerContracts[borrower]; 
    delete lenderContracts[lender]; 
  }
  // slither-disable-end reentrancy-no-eth

  function getAddressOfBorrowerContract(address borrower) public view returns (address) {
    return address(borrowerContracts[borrower]);
  }

  function getAddressOfLenderContract(address lender) public view returns (address) {
    return address(lenderContracts[lender]);
  }

  function lendToTokenBorrower(address lender, bondRequest memory request) public {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    
    uint borrowedAmount = (priceOracleManager.getPrice(request.collatralAmount, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, request.borrowingtoken) * request.borrowingPercentage) / 100;
    
    lenderContracts[lender] = new Lender(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      borrowedAmount,
      request.durationInHours,
      request.intrestYearly
    );
    borrowerContracts[request.borrower] = new Borrower(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      borrowedAmount,
      request.durationInHours,
      request.intrestYearly
    );

    requestManager.deleteBondRequest(uint(index));

    bool status = tokenBank.spendAllowedTokens(request.borrowingtoken, lender, address(borrowerContracts[request.borrower]), borrowedAmount); 
    require(status, 'transferFrom failed');
    if(request.collatralToken == address(1)) {
      requestManager.sendFromBondContractsManager(payable(address(lenderContracts[lender])), request.collatralAmount);
    } else {
      bool status = requestManager.sendTokenFromBondContractsManager(request.collatralToken, request.borrower, address(lenderContracts[lender]), request.collatralAmount);
      require(status, 'transfer failed');
    }
  }

  function lendToETHBorrower(address lender, bondRequest memory request) public payable {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');

    uint borrowedAmount = (priceOracleManager.getPrice(request.collatralAmount, request.collatralToken, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1) * request.borrowingPercentage) / 100; 

    lenderContracts[lender] = new Lender(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      borrowedAmount,
      request.durationInHours,
      request.intrestYearly
    );
    borrowerContracts[request.borrower] = new Borrower(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      borrowedAmount,
      request.durationInHours,
      request.intrestYearly
    );
    requestManager.deleteBondRequest(uint(index));

    sendViaCall(payable(address(borrowerContracts[request.borrower])), borrowedAmount);
    bool status = requestManager.sendTokenFromBondContractsManager(request.collatralToken, request.borrower, address(lenderContracts[lender]), request.collatralAmount);
    require(status, 'transfer failed');
  }
}
