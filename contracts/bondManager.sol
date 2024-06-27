// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

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
    BondInterface bondContractInstance = BondInterface(bondContractsManager.getAddressOfLenderContract());
    uintPair[] memory bondPairs = bondContractsManager.getBondPairs();
    uint len = bondPairs.length;
    
    // slither-disable-start calls-loop
    for(uint i; i < len; i++) { 
      bool yes = testing || bondContractInstance.isUnderCollateralized() || bondContractInstance.hasMatured();
      if(yes) {
        bondContractsManager.liquidate(bondPairs[i].borrowerId, bondPairs[i].lenderId);
      }
    }
    // slither-disable-end calls-loop
  }
  // slither-disable-end reentrancy-no-eth
}
