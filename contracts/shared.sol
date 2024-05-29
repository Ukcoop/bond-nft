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
    liquidated = false;
    borrowed = 0;
  }

  function getData() public view returns (getDataResponse memory) {
    return getDataResponse(borrower, lender, collatralToken, borrowingToken, collatralAmount, borrowingAmount, durationInHours, intrestYearly);
  }
}
