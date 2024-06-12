// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '../tokenBank.sol';
import '../shared.sol';
import '../borrowerNFT.sol';
import '../lenderNFT.sol';
import './requestManager.sol';

contract BondContractsManager is HandlesETH {
  mapping(address => Borrower) public borrowerContracts;
  mapping(address => Lender) public lenderContracts;
  TokenBank immutable tokenBank;
  RequestManager immutable requestManager;
  address immutable deployer;
  address bondManagerAddress;
  
  constructor(address _tokenBank, address _requestManager) {
    tokenBank = TokenBank(_tokenBank);
    requestManager = RequestManager(_requestManager);
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

  function lendToETHToTokenBorrower(address lender, bondRequest memory request) public payable {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');

    lenderContracts[lender] = new Lender(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );
    borrowerContracts[request.borrower] = new Borrower(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );

    requestManager.deleteBondRequest(uint(index));

    bool status = tokenBank.spendAllowedTokens(request.borrowingtoken, lender, address(borrowerContracts[request.borrower]), request.borrowingAmount); 
    require(status, 'transferFrom failed');
    require(address(requestManager).balance >= request.collatralAmount, 'Contract does not have enough Ether');
    require(request.collatralAmount > 0, 'ETHAmount should be greater than zero');
    requestManager.sendFromBondContractsManager(payable(address(lenderContracts[lender])), request.collatralAmount);
  }

  function lendToTokenToETHBorrower(address lender, bondRequest memory request) public payable {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    require(msg.value >= request.borrowingAmount, 'not enough ETH was sent');

    lenderContracts[lender] = new Lender(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );
    borrowerContracts[request.borrower] = new Borrower(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );
    requestManager.deleteBondRequest(uint(index));

    sendViaCall(payable(address(borrowerContracts[request.borrower])), request.borrowingAmount);
    bool status = requestManager.sendTokenFromBondContractsManager(request.collatralToken, request.borrower, address(lenderContracts[lender]), request.collatralAmount);
    require(status, 'transfer failed');
  }

  function lendToTokenToTokenBorrower(address lender, bondRequest memory request) public {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');

    lenderContracts[lender] = new Lender(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );
    borrowerContracts[request.borrower] = new Borrower(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );
    requestManager.deleteBondRequest(uint(index));

    bool status1 = tokenBank.spendAllowedTokens(request.borrowingtoken, lender, address(borrowerContracts[request.borrower]), request.borrowingAmount);
    bool status2 = requestManager.sendTokenFromBondContractsManager(request.collatralToken, request.borrower, address(lenderContracts[lender]), request.collatralAmount);
    require(status1 && status2, 'transferFrom failed');
  }
}
