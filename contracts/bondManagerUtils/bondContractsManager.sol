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
  mapping(uint32 => bool) internal lenderCanBurn;
  mapping(uint => bondData) bondContractsData;
  uint32 internal bondIds;
  LenderNFTManager internal immutable lenderNFTManager;
  BorrowerNFTManager internal immutable borrowerNFTManager;
  uintPair[] internal bondPairs;
  TokenBank internal immutable tokenBank;
  PriceOracleManager internal immutable priceOracleManager; 
  RequestManager internal immutable requestManager;
  address internal bondManagerAddress;
  address internal immutable deployer;
  
  constructor(address _tokenBank, address _priceOracleManager, address _testingHelper, address _requestManager) {
    lenderNFTManager = new LenderNFTManager();
    borrowerNFTManager = new BorrowerNFTManager(address(lenderNFTManager), _priceOracleManager, _testingHelper);
    lenderNFTManager.setAddress(address(borrowerNFTManager), _priceOracleManager, _testingHelper);
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

  function getNextId() internal returns(uint32) {
    uint32 len = bondIds;
    for(uint32 i = 0; i < len; i++) {
      // that is not a timestamp slither...
      //slither-disable-next-line timestamp
      if(bondContractsData[i].owner == address(0)) {
        return i;
      }
    }
    return bondIds++;
  }

  function createBond(uint32 bondId, uint32 borrowerId, uint32 lenderId, uint borrowedAmount, bondRequest memory request) internal {
    bondContractsData[bondId] = bondData(borrowerId, lenderId, request.durationInHours, request.intrestYearly, uint32(block.timestamp), address(this), request.collatralToken, request.borrowingToken, request.collatralAmount, borrowedAmount, 0, borrowedAmount, false);
  }

  function getBondData(uint32 bondId) public view returns (bondData memory) {
    return bondContractsData[bondId];
  }

  function setBondData(uint32 bondId, bondData memory data) public {
    require(msg.sender == borrowerNFTManager.getContractAddress() || msg.sender == lenderNFTManager.getContractAddress(), 'you are not authorized to do this action');
    bondContractsData[bondId] = data;
  } 

  // slither-disable-start costly-loop
  function deleteBondPair(uint32 borrowerId, uint32 lenderId) internal {
    uint index = 0;
    // i can at least read from bondPairs once, but i can't write only once.
    uintPair[] memory _bondPairs = bondPairs;
    uint len = _bondPairs.length;
    for(uint i; i < len; i++) {
      if(_bondPairs[i].borrowerId == borrowerId && _bondPairs[i].lenderId == lenderId) {
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

  function liquidate(uint32 borrowerId, uint32 lenderId) public {
    require(msg.sender == bondManagerAddress, 'you are not authorized to do this action');
    deleteBondPair(borrowerId, lenderId);
    lenderCanBurn[lenderId] = true;
    Borrower borrower = Borrower(borrowerNFTManager.getContractAddress());
    Lender lender = Lender(lenderNFTManager.getContractAddress());
    bondData memory res = lender.getData(lenderId);
    require(res.borrowerId == borrowerId, 'the lender does not have this address as the borrower');
    borrower.liquidate(borrowerId, address(lender));
    lender.liquidate(lenderId);
    borrowerNFTManager.burnBorrowerContract(borrowerId); 
  }
  
  function burnFromLender(uint32 lenderId) public {
    require(msg.sender == lenderNFTManager.getContractAddress(), 'you are not authorized to do this action');
    require(lenderCanBurn[lenderId], 'lender can not burn');
    lenderNFTManager.burnLenderContract(lenderId); 
  }

  function getBorrowersIds() public view returns (uint32[] memory) {
    return borrowerNFTManager.getIds(msg.sender);
  }

  function getLendersIds() public view returns (uint32[] memory) {
    return lenderNFTManager.getIds(msg.sender);
  }

  function getAddressOfBorrowerContract() public view returns (address) {
    return borrowerNFTManager.getContractAddress();
  }

  function getAddressOfLenderContract() public view returns (address) {
    return lenderNFTManager.getContractAddress();
  }

  // slither-disable-start reentrancy-benign
  // slither-disable-start reentrancy-no-eth
  function lendToBorrower(bondRequest memory request) public payable nonReentrant {
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    
    uint borrowedAmount = requestManager.getRequiredAmountForRequest(request);
    uint32 bondId = getNextId();
    uint32 lenderId = lenderNFTManager.getNextId();
    uint32 borrowerId = borrowerNFTManager.getNextId();
    bondPairs.push(uintPair(borrowerId, lenderId));


    createBond(bondId, borrowerId, lenderId, borrowedAmount, request);
    lenderNFTManager.createLenderNFT(msg.sender, bondId, lenderId);
    borrowerNFTManager.createBorrowerNFT(request.borrower, bondId, borrowerId); 

    requestManager.deleteBondRequest(uint(index));

    address lenderContractAddress = lenderNFTManager.getContractAddress();
    address borrowerContractAddress = borrowerNFTManager.getContractAddress();
    
    bool status = false;
    if(request.borrowingToken != address(1)) {
      status = tokenBank.spendAllowedTokens(request.borrowingToken, msg.sender, borrowerContractAddress, borrowedAmount);
    } else {
      sendViaCall(payable(borrowerContractAddress), borrowedAmount);
      status = true;
    }
    require(status, 'transferFrom failed');
    
    if(request.collatralToken == address(1)) {
      requestManager.sendFromBondContractsManager(payable(lenderContractAddress), request.collatralAmount);
    } else {
      status = requestManager.sendTokenFromBondContractsManager(request.collatralToken, request.borrower, lenderContractAddress, request.collatralAmount);
      require(status, 'transfer failed');
    }
  }
  // slither-disable-end reentrancy-benign
  // slither-disable-end reentrancy-no-eth

  function withdraw(uint32 id) public {
    Lender lenderContract = Lender(lenderNFTManager.getContractAddress());
    lenderContract.withdraw(msg.sender, id);
  }
}
