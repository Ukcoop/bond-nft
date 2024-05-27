// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Borrower {
  address immutable collatralToken; // this will be address(1) for native eth
  address immutable borrowingToken;
  uint256 immutable borrowingAmount;
  uint256 immutable durationInHours;
  uint256 immutable intrestYearly;
  address immutable lender;

  constructor(address lender1, address collatralToken1, address borrowingToken1,uint borrowingAmount1, uint256 durationInHours1, uint256 intrestYearly1) {
    require(lender1 != address(0), 'lender address can not be address(0)');
    require(collatralToken1 != address(0), 'collatral token can not be address(0)');
    require(borrowingToken1 != address(0), 'borrowing token can not be address(0)');
    require(borrowingAmount1 != 0, 'cant borrow nothing');
    require(durationInHours1 > 24, 'bond length is too short');
    require(intrestYearly1 > 2 && intrestYearly1 < 15, 'intrest is not in this range: (2 to 15)%');
    collatralToken = collatralToken1;
    borrowingToken = borrowingToken1;
    borrowingAmount = borrowingAmount1;
    durationInHours = durationInHours1;
    intrestYearly = intrestYearly1;
    lender  = lender1;
  }
  receive() external payable {}
}


