// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

//import './borrowerNFT.sol';
import './lenderNFT.sol';
import './shared.sol';
import './bondManagerUtils/requestManager.sol';
import './bondManagerUtils/bondContractsManager.sol';

contract BondManager is AutomationCompatibleInterface {
  bool internal immutable testing;
  RequestManager internal immutable requestManager;
  BondContractsManager internal immutable bondContractsManager;
  address internal immutable tokenBank;

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
    uint32 borrowingPercentage,
    uint32 termInHours,
    uint32 intrestYearly
  ) public payable returns (bool) {
    return requestManager.postETHToTokenbondRequest{value: msg.value}(msg.sender, borrowingToken, borrowingPercentage, termInHours, intrestYearly);
  }

  function postTokenToETHBondRequest(
    address collatralToken,
    uint collatralAmount,
    uint32 borrowingPercentage,
    uint32 termInHours,
    uint32 intrestYearly
  ) public returns (bool) {
    return requestManager.postTokenToETHBondRequest(msg.sender, collatralToken, collatralAmount, borrowingPercentage, termInHours, intrestYearly);
  }

  function postTokenToTokenbondRequest(
    address collatralToken,
    uint collatralAmount,
    address borrowingToken,
    uint32 borrowingPercentage,
    uint32 termInHours,
    uint32 intrestYearly
  ) public returns (bool) {
    return requestManager.postTokenToTokenbondRequest(msg.sender, collatralToken, collatralAmount, borrowingToken, borrowingPercentage, termInHours, intrestYearly);
  }

  function getBorrowersIds() public view returns (uint32[] memory) {
    return bondContractsManager.getBorrowersIds(msg.sender);
  }

  function getLendersIds() public view returns (uint32[] memory) {
    return bondContractsManager.getLendersIds(msg.sender);
  }

  function getAddressOfBorrowerContract() public view returns (address) {
    return bondContractsManager.getAddressOfBorrowerContract();
  }

  function getAddressOfLenderContract() public view returns (address) {
    return bondContractsManager.getAddressOfBorrowerContract();
  }

  // slither-disable-start calls-loop
  function liquidate(uint32 borrowerId, uint32 lenderId) internal {
    bondContractsManager.liquidate(borrowerId, lenderId);
  }
  // slither-disable-end calls-loop
  
  function getRequiredLquidations() internal view returns (bool upkeepNeeded, bytes memory data) {
    upkeepNeeded = false;
    data = bytes('');
    uintPair[] memory bondPairs = bondContractsManager.getBondPairs();
    uint len = bondPairs.length;

    for(uint i; i < len; i++) {
      BondInterface bondContractInstance = BondInterface(bondContractsManager.getAddressOfLenderContract());
      bool yes = testing || bondContractInstance.isUnderCollateralized() || bondContractInstance.hasMatured();
      if(yes) {
        upkeepNeeded = true;
      }
    }
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
    for(uint i; i < len; i++) {
      BondInterface bondContractInstance = BondInterface(bondContractsManager.getAddressOfLenderContract());
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

  function withdrawLentTokens(uint32 id) public {
    bondContractsManager.withdrawLentTokens(msg.sender, id);
  }

  function withdrawLentETH(uint32 id) public {
    bondContractsManager.withdrawLentETH(msg.sender, id);
  }
}
