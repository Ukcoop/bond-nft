// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import './borrowerNFT.sol';
import './lenderNFT.sol';
import './shared.sol';
import './bondManagerUtils/requestManager.sol';
import './bondManagerUtils/bondContractsManager.sol';

struct addressPair {
  address borrower;
  address lender;
}

contract BondManager is AutomationCompatibleInterface {
  mapping(address => Borrower) public borrowerContracts;
  mapping(address => Lender) public lenderContracts;
  addressPair[] bondPairs;
  bool immutable testing;
  RequestManager immutable requestManager;
  BondContractsManager immutable bondContractsManager;

  constructor(address _requestManagerAddress, address _bondContractsManagerAddress, bool _testing) {
    requestManager = RequestManager(_requestManagerAddress);
    bondContractsManager = BondContractsManager(_bondContractsManagerAddress);
    testing = _testing;
  }

  function getRequestManagerAddress() public view returns (address) {
    return address(requestManager);
  }

  function getBondContractsManagerAddress() public view returns (address) {
    return address(bondContractsManager);
  }

  function postETHToTokenbondRequest(
    address borrowingToken,
    uint borrowingAmount,
    uint termInHours,
    uint intrestYearly
  ) public payable returns (bool) {
    return requestManager.postETHToTokenbondRequest{value: msg.value}(msg.sender, borrowingToken, borrowingAmount, termInHours, intrestYearly);
  }

  function postTokenToETHBondRequest(
    address collatralToken,
    uint collatralAmount,
    uint borrowingAmount,
    uint termInHours,
    uint intrestYearly
  ) public returns (bool) {
    return requestManager.postTokenToETHBondRequest(msg.sender, collatralToken, collatralAmount, borrowingAmount, termInHours, intrestYearly);
  }

  function postTokenToTokenbondRequest(
    address collatralToken,
    uint collatralAmount,
    address borrowingToken,
    uint borrowingAmount,
    uint termInHours,
    uint intrestYearly
  ) public returns (bool) {
    return requestManager.postTokenToTokenbondRequest(msg.sender, collatralToken, collatralAmount, borrowingToken, borrowingAmount, termInHours, intrestYearly);
  }

  function getAddressOfBorrowerContract(address borrower) public view returns (address) {
    return bondContractsManager.getAddressOfBorrowerContract(borrower);
  }

  function getAddressOfLenderContract(address lender) public view returns (address) {
    return bondContractsManager.getAddressOfLenderContract(lender);
  }

  function liquidateFromBorrower(address borrower, address lender) public {
    require(msg.sender == borrower, 'you are not authorized to do this action');
    bondContractsManager.liquidate(borrower, lender);
  }
  
  // slither-disable-start costly-loop
  function deleteBondPair(address borrower, address lender) internal {
    uint index = 0;
    uint len = bondPairs.length;
    for(uint i = 0; i < len; i++) {
      if(bondPairs[i].borrower == borrower && bondPairs[i].lender == lender) {
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

  // slither-disable-start calls-loop
  function liquidate(address borrower, address lender) internal {
    bondContractsManager.liquidate(borrower, lender);
  }
  // slither-disable-end calls-loop
  
  function getRequiredLquidations() internal view returns (bool, bytes memory) {
    bool upkeepNeeded = false;
    uint len = bondPairs.length;

    for(uint i = 0; i < len; i++) {
      BondInterface bondContractInstance = BondInterface(bondContractsManager.getAddressOfLenderContract(bondPairs[i].lender));
      bool yes = testing || bondContractInstance.hasMatured();
      if(yes) {
        upkeepNeeded = true;
      }
    }

    return (upkeepNeeded, bytes(''));
  }

  function checkUpkeepWithNoCallData() public view returns (bool, bytes memory) {
    return getRequiredLquidations();
  }  

  function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
    return getRequiredLquidations();
  }
  
  // slither-disable-start reentrancy-no-eth
  function performUpkeep(bytes calldata) external override {
    uint len = bondPairs.length;
    
    // slither-disable-start calls-loop
    for(uint i = 0; i < len; i++) {
      BondInterface bondContractInstance = BondInterface(bondContractsManager.getAddressOfLenderContract(bondPairs[i].lender));
      bool yes = testing || bondContractInstance.hasMatured();
      if(yes) {
        liquidate(bondPairs[i].borrower, bondPairs[i].lender);
        deleteBondPair(bondPairs[i].borrower, bondPairs[i].lender);
      }
    }
    // slither-disable-end calls-loop
  }
  // slither-disable-end reentrancy-no-eth

  function cancelETHToTokenBondRequest(bondRequest memory request) public returns (bool) {
    return requestManager.cancelETHToTokenBondRequest(msg.sender, request);
  }

  function cancelTokenToTokenBondRequest(bondRequest memory request) public payable returns (bool) {
    return requestManager.cancelTokenToTokenBondRequest(msg.sender, request);
  }

  function getBondRequests() public view returns (bondRequest[] memory) {
    return requestManager.getBondRequests();
  }

  function lendToETHToTokenBorrower(bondRequest memory request) public payable {
    bondPairs.push(addressPair(request.borrower,msg.sender));
    bondContractsManager.lendToETHToTokenBorrower(msg.sender, request); 
  }

  function lendToTokenToETHBorrower(bondRequest memory request) public payable {
    bondPairs.push(addressPair(request.borrower,msg.sender));
    bondContractsManager.lendToTokenToETHBorrower{value: msg.value}(msg.sender, request);
  }

  function lendToTokenToTokenBorrower(bondRequest memory request) public {
    bondPairs.push(addressPair(request.borrower,msg.sender));
    bondContractsManager.lendToTokenToTokenBorrower(msg.sender, request);
  }
}
