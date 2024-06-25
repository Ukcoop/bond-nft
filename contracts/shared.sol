// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import './priceOracleManager.sol';
import './bondManagerUtils/bondContractsManager.sol';

struct getDataResponse {
  uint32 borrowerId;
  uint32 lenderId;
  address collatralToken;
  address borrowingToken;
  uint256 collatralAmount;
  uint256 borrowingAmount;
  uint32 durationInHours;
  uint32 intrestYearly;
}

struct uintPair {
  uint32 borrowerId;
  uint32 lenderId;
}

struct bondRequest {
  address borrower;
  address collatralToken;
  uint256 collatralAmount;
  address borrowingToken;
  uint32 borrowingPercentage;
  uint32 durationInHours;
  uint32 intrestYearly;
}

struct bondData {
  uint32 borrowerId;
  uint32 lenderId;
  uint32 durationInHours;
  uint32 intrestYearly;
  uint32 startTime;
  address owner;
  address collatralToken; // this will be address(1) for native eth
  address borrowingToken; // this will be address(1) for native eth
  uint256 collatralAmount;
  uint256 borrowingAmount;
  uint256 borrowed;
  uint256 total;
  bool liquidated;
}

interface BondInterface {
  function getData() external view returns (getDataResponse memory);
  function getOwed() external view returns (uint);
  function hasMatured() external view returns (bool);
  function isUnderCollateralized() external view returns (bool);
}

interface NFTManagerInterface {
  function getOwner(uint32 id) external view returns (address);
  function getContractAddress() external view returns (address payable);
}

abstract contract HandlesETH {
  //receive() external payable {}
  
  // slither-disable-start low-level-calls
  // slither-disable-start arbitrary-send-eth 
  function sendViaCall(address to, uint value) internal {
    require(to != address(0), 'cant send to the 0 address');
    require(value != 0, 'can not send nothing');
    (bool sent,) = payable(to).call{value: value}('');
    require(sent, 'Failed to send Ether');
  }
  // slither-disable-end low-level-calls
  // slither-disable-end arbitrary-send-eth 
}

contract Bond {
  mapping(uint32 => uint32) internal toBondId;
  PriceOracleManager internal immutable priceOracleManager;
  NFTManagerInterface internal immutable lenderNFTManager;
  NFTManagerInterface internal immutable borrowerNFTManager;
  BondContractsManager immutable owner;  

  constructor(address _lenderNFTManager, address _borrowerNFTManager, address _bondContractsManager, address _priceOracleManager) {
    lenderNFTManager = NFTManagerInterface(_lenderNFTManager);
    borrowerNFTManager = NFTManagerInterface(_borrowerNFTManager);
    priceOracleManager = PriceOracleManager(_priceOracleManager);
    owner = BondContractsManager(_bondContractsManager);
  }

  function setBondId(uint32 bondId, uint32 nftId) public {
    require(msg.sender == address(lenderNFTManager) || msg.sender == address(borrowerNFTManager), ' you are not authorized to do this action');
    toBondId[nftId] = bondId; 
  }

  function getBondData(uint32 id) internal view returns(bondData memory) {
    return owner.getBondData(toBondId[id]);
  }

  function setBondData(uint32 id, bondData memory data) internal {
    owner.setBondData(toBondId[id], data);
  }

  function getData(uint32 id) public view returns (getDataResponse memory) {
    bondData memory data = getBondData(id);
    return getDataResponse(data.borrowerId, data.lenderId, data.collatralToken, data.borrowingToken, data.collatralAmount, data.borrowingAmount, data.durationInHours, data.intrestYearly);
  }
  
  // slither-disable-start timestamp
  // slither-disable-start divide-before-multiply
  // slither-disable-start assembly
  function getOwed(uint32 id) public view returns (uint owed) { // this might not be working correctly, need more resolution on the intrest.
    bondData memory data = getBondData(id);
    uint start = data.startTime;
    uint intrest = data.intrestYearly;
    uint borrowing = data.borrowingAmount;
    assembly {
      let currentTime := timestamp()
      let elapsedTime := div(sub(currentTime, start), 3600)
      let interestRatePerHour := div(intrest, 8760)
      let interestAccrued := div(mul(interestRatePerHour, elapsedTime), 100)
      let totalOwed := mul(borrowing, add(1, interestAccrued))
      owed := totalOwed
    }
  }
  // slither-disable-end divide-before-multiply
  // slither-disable-end assembly

  function hasMatured(uint32 id) public view returns (bool) {
    bondData memory data = getBondData(id);
    return ((block.timestamp - data.startTime) / 3600) >= data.durationInHours;
  }
  // slither-disable-end timestamp

  function isUnderCollateralized(uint32 id) public view returns (bool) {
    bondData memory data = getBondData(id);
    if(data.borrowed == 0) return false;
    uint collatralValue = priceOracleManager.getPrice(data.collatralAmount, (data.collatralToken == address(1) ? 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 : data.collatralToken),
                                                                       (data.borrowingToken == address(1) ? 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 : data.borrowingToken));
    return ((data.borrowed * 100) / (collatralValue * 100)) >= 90;
  }

  // slither-disable-start low-level-calls
  // slither-disable-start arbitrary-send-eth
  function sendETHToBorrower(uint32 id, uint value) internal {
    bondData memory data = getBondData(id);
    require(value != 0, 'cannot send nothing');
    (bool sent,) = payable(borrowerNFTManager.getOwner(data.borrowerId)).call{value: value}('');// the owner of the nft is the only address that this function will send eth to.
    require(sent, 'Failed to send Ether');
  }

  function sendETHToLender(uint32 id, uint value) internal {
    bondData memory data = getBondData(id);
    require(value != 0, 'cannot send nothing');
    (bool sent,) = payable(lenderNFTManager.getOwner(data.lenderId)).call{value: value}('');// the owner of the nft is the only address that this function will send eth to.
    require(sent, 'Failed to send Ether');
  }

  // slither-disable-end low-level-calls
  // slither-disable-end arbitrary-send-eth
}
