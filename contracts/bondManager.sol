// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import './borrowerNFT.sol';
import './lenderNFT.sol';
import './shared.sol';
import './bondManagerUtils/requestManager.sol';
import './bondManagerUtils/bondContractsManager.sol';

contract BondManager is AutomationCompatibleInterface {
  bool immutable testing;
  RequestManager immutable requestManager;
  BondContractsManager immutable bondContractsManager;
  address immutable tokenBank;

  constructor(address _requestManager, address _bondContractsManager, address _tokenBank, bool _testing) {
    require(_requestManager != address(0), 'requestManager address can not be 0');
    require(_bondContractsManager != address(0), 'bondContractsManager address can not be 0');
    require(_tokenBank != address(0), 'tokenBank address can not be 0');
    requestManager = RequestManager(_requestManager);
    bondContractsManager = BondContractsManager(_bondContractsManager);
    tokenBank = _tokenBank;
    testing = _testing;
  }

  function getRequestManagerAddress() public view returns (address) {
    return address(requestManager);
  }

  function getBondContractsManagerAddress() public view returns (address) {
    return address(bondContractsManager);
  }

  function getTokenBankAddress() public view returns (address) {
    return address(tokenBank);
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

  function getBorrowersIds() public view returns (uint[] memory) {
    return bondContractsManager.getBorrowersIds(msg.sender);
  }

  function getLendersIds() public view returns (uint[] memory) {
    return bondContractsManager.getLendersIds(msg.sender);
  }

  function getAddressOfBorrowerContract(uint id) public view returns (address) {
    return bondContractsManager.getAddressOfBorrowerContract(id);
  }

  function getAddressOfLenderContract(uint id) public view returns (address) {
    return bondContractsManager.getAddressOfBorrowerContract(id);
  }

//  function liquidateFromBorrower(uint borrowerId, uint lenderId) public {
//    require(msg.sender == borrower, 'you are not authorized to do this action');
//    bondContractsManager.liquidate(borrowerId, lenderId);
//  }

  // slither-disable-start calls-loop
  function liquidate(uint borrowerId, uint lenderId) internal {
    bondContractsManager.liquidate(borrowerId, lenderId);
  }
  // slither-disable-end calls-loop
  
  function getRequiredLquidations() internal view returns (bool, bytes memory) {
    bool upkeepNeeded = false;
    uintPair[] memory bondPairs = bondContractsManager.getBondPairs();
    uint len = bondPairs.length;

    for(uint i = 0; i < len; i++) {
      BondInterface bondContractInstance = BondInterface(bondContractsManager.getAddressOfLenderContract(bondPairs[i].lenderId));
      bool yes = testing || bondContractInstance.isUnderCollateralized() || bondContractInstance.hasMatured();
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
    uintPair[] memory bondPairs = bondContractsManager.getBondPairs();
    uint len = bondPairs.length;
    
    // slither-disable-start calls-loop
    for(uint i = 0; i < len; i++) {
      BondInterface bondContractInstance = BondInterface(bondContractsManager.getAddressOfLenderContract(bondPairs[i].lenderId));
      bool yes = testing || bondContractInstance.isUnderCollateralized() || bondContractInstance.hasMatured();
      if(yes) {
        liquidate(bondPairs[i].borrowerId, bondPairs[i].lenderId);
      }
    }
    // slither-disable-end calls-loop
  }
  // slither-disable-end reentrancy-no-eth

  function cancelETHCollatralizedBondRequest(bondRequest memory request) public returns (bool) {
    return requestManager.cancelETHCollatralizedBondRequest(msg.sender, request);
  }

  function cancelTokenCollatralizedBondRequest(bondRequest memory request) public payable returns (bool) {
    return requestManager.cancelTokenCollatralizedBondRequest(msg.sender, request);
  }

  function getBondRequests() public view returns (bondRequest[] memory) {
    return requestManager.getBondRequests();
  }

  function getRequiredAmountForRequest(bondRequest memory request) public view returns (uint) {
    return requestManager.getRequiredAmountForRequest(request); 
  }

  function lendToTokenBorrower(bondRequest memory request) public payable {
    bondContractsManager.lendToTokenBorrower(msg.sender, request); 
  }

  function lendToETHBorrower(bondRequest memory request) public payable {
    bondContractsManager.lendToETHBorrower{value: msg.value}(msg.sender, request);
  }
}
