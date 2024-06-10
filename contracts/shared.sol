// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct getDataResponse {
  address borrower;
  address lender;
  address collatralToken;
  address borrowingToken;
  uint256 collatralAmount;
  uint256 borrowingAmount;
  uint256 durationInHours;
  uint256 intrestYearly;
}

interface BondInterface {
  function getData() external view returns (getDataResponse memory);
  function getOwed() external view returns (uint);
  function hasMatured() external view returns (bool);
}

contract Bond {
  address immutable borrower;
  address immutable lender;
  address immutable owner;
  address immutable collatralToken; // this will be address(1) for native eth
  address immutable borrowingToken;
  uint256 immutable borrowingAmount;
  uint256 immutable collatralAmount;
  uint256 immutable durationInHours;
  uint256 immutable intrestYearly;
  uint256 immutable startTime;
  //slither-disable-next-line immutable-states
  uint256 borrowed;
  bool liquidated;

  constructor(address borrower1, address lender1, address collatralToken1, address borrowingToken1, uint borrowingAmount1, uint collatralAmount1, uint durationInHours1, uint intrestYearly1) {
    require(borrower1 != address(0), 'borrower address can not be address(0)');
    require(lender1 != address(0), 'lender address can not be address(0)');
    require(collatralToken1 != address(0), 'collatral token can not be address(0)');
    require(borrowingToken1 != address(0), 'borrowing token can not be address(0)');
    require(borrowingAmount1 != 0, 'cant borrow nothing');
    require(durationInHours1 > 24, 'bond length is too short');
    require(intrestYearly1 > 2 && intrestYearly1 < 15, 'intrest is not in this range: (2 to 15)%');
    borrower = borrower1;
    lender = lender1;
    owner = msg.sender;
    collatralToken = collatralToken1;
    borrowingToken = borrowingToken1;
    borrowingAmount = borrowingAmount1;
    collatralAmount = collatralAmount1;
    durationInHours = durationInHours1;
    intrestYearly = intrestYearly1;
    startTime = block.timestamp;
    liquidated = false;
    borrowed = 0;
  }

  function getData() public view returns (getDataResponse memory) {
    return getDataResponse(borrower, lender, collatralToken, borrowingToken, collatralAmount, borrowingAmount, durationInHours, intrestYearly);
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

  // slither-disable-start low-level-calls
  // slither-disable-start arbitrary-send-eth
  function sendETHToBorrower(uint value) internal {
    require(value != 0, 'cannot send nothing');
    (bool sent,) = payable(borrower).call{value: value}('');// since the borrower variable is immutable and only set by the bondManager, this is a false positive
    require(sent, 'Failed to send Ether');
  }

  function sendETHToLender(uint value) internal {
    require(value != 0, 'cannot send nothing');
    (bool sent,) = payable(lender).call{value: value}('');// since the borrower variable is immutable and only set by the bondManager, this is a false positive
    require(sent, 'Failed to send Ether');
  }

  // slither-disable-end low-level-calls
  // slither-disable-end arbitrary-send-eth
}
