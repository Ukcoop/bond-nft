// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import './priceOracleManager.sol';

struct getDataResponse {
  uint256 borrowerId;
  uint256 lenderId;
  address collatralToken;
  address borrowingToken;
  uint256 collatralAmount;
  uint256 borrowingAmount;
  uint256 durationInHours;
  uint256 intrestYearly;
}

struct uintPair {
  uint borrowerId;
  uint lenderId;
}

interface BondInterface {
  function getData() external view returns (getDataResponse memory);
  function getOwed() external view returns (uint);
  function hasMatured() external view returns (bool);
  function isUnderCollateralized() external view returns (bool);
}

interface NFTManagerInterface {
  function getOwner(uint id) external view returns (address);
  function getContractAddress(uint id) external view returns (address payable);
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
  uint256 immutable borrowerId;
  uint256 immutable lenderId;
  address immutable owner;
  address immutable collatralToken; // this will be address(1) for native eth
  address immutable borrowingToken; // this will be address(1) for native eth
  uint256 immutable borrowingAmount;
  uint256 immutable collatralAmount;
  uint256 immutable durationInHours;
  uint256 immutable intrestYearly;
  uint256 immutable startTime;
  PriceOracleManager immutable priceOracleManager;
  NFTManagerInterface immutable lenderNFTManager;
  NFTManagerInterface immutable borrowerNFTManager;
  //slither-disable-next-line immutable-states
  uint256 borrowed;
  bool liquidated;

  constructor(address _lenderNFTManager, address _borrowerNFTManager, address bondContractsManager, address _priceOracleManager, uint _borrowerId, uint _lenderId, address _collatralToken, address _borrowingToken, uint _borrowingAmount, uint _collatralAmount, uint _durationInHours, uint _intrestYearly) {
    require(_collatralToken != address(0), 'collatral token can not be address(0)');
    require(_borrowingToken != address(0), 'borrowing token can not be address(0)');
    require(_borrowingAmount != 0, 'cant borrow nothing');
    require(_durationInHours > 24, 'bond length is too short');
    require(_intrestYearly > 2 && _intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');
    borrowerId = _borrowerId;
    lenderId = _lenderId;
    owner = bondContractsManager;
    collatralToken = _collatralToken;
    borrowingToken = _borrowingToken;
    borrowingAmount = _borrowingAmount;
    collatralAmount = _collatralAmount;
    durationInHours = _durationInHours;
    intrestYearly = _intrestYearly;
    startTime = block.timestamp;
    lenderNFTManager = NFTManagerInterface(_lenderNFTManager);
    borrowerNFTManager = NFTManagerInterface(_borrowerNFTManager);
    priceOracleManager = PriceOracleManager(_priceOracleManager);
    liquidated = false;
    borrowed = 0;
  }

  function getData() public view returns (getDataResponse memory) {
    return getDataResponse(borrowerId, lenderId, collatralToken, borrowingToken, collatralAmount, borrowingAmount, durationInHours, intrestYearly);
  }
  
  // slither-disable-start timestamp
  // slither-disable-start divide-before-multiply
  // slither-disable-start assembly
  function getOwed() public view returns (uint owed) {
    uint start = startTime;
    uint intrest = intrestYearly;
    uint borrowing = borrowingAmount;
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

  function hasMatured() public view returns (bool) {
    return ((block.timestamp - startTime) / 3600) >= durationInHours;
  }
  // slither-disable-end timestamp

  function isUnderCollateralized() public view returns (bool) {
    if(borrowed == 0) return false;
    uint collatralValue = priceOracleManager.getPrice(collatralAmount, (collatralToken == address(1) ? 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 : collatralToken),
                                                                       (borrowingToken == address(1) ? 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 : borrowingToken));
    return ((borrowed * 100) / (collatralValue * 100)) >= 90;
  }

  // slither-disable-start low-level-calls
  // slither-disable-start arbitrary-send-eth
  function sendETHToBorrower(uint value) internal {
    require(value != 0, 'cannot send nothing');
    (bool sent,) = payable(borrowerNFTManager.getOwner(borrowerId)).call{value: value}('');// the owner of the nft is the only address that this function will send eth to.
    require(sent, 'Failed to send Ether');
  }

  function sendETHToLender(uint value) internal {
    require(value != 0, 'cannot send nothing');
    (bool sent,) = payable(lenderNFTManager.getOwner(lenderId)).call{value: value}('');// the owner of the nft is the only address that this function will send eth to.
    require(sent, 'Failed to send Ether');
  }

  // slither-disable-end low-level-calls
  // slither-disable-end arbitrary-send-eth
}
