// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './bondManager.sol';

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

contract Borrower {
  address immutable collatralToken; // this will be address(1) for native eth
  address immutable borrowingToken;
  uint256 immutable collatralAmount;
  uint256 immutable borrowingAmount;
  uint256 immutable durationInHours;
  uint256 immutable intrestYearly;
  address immutable borrower;
  address immutable lender;
  address immutable owner;
  uint256 borrowed;
  bool liquidated;

  event Withdraw(address borrower, uint amount);
  event Deposit(address sender, address borrower, uint amount);

  constructor(address borrower1, address lender1, address collatralToken1, address borrowingToken1, uint collatralAmount1, uint borrowingAmount1, uint256 durationInHours1, uint256 intrestYearly1) {
    require(borrower1 != address(0), 'borrower address can not be address(0)');
    require(lender1 != address(0), 'lender address can not be address(0)');
    require(collatralToken1 != address(0), 'collatral token can not be address(0)');
    require(borrowingToken1 != address(0), 'borrowing token can not be address(0)');
    require(borrowingAmount1 != 0, 'cant borrow nothing');
    require(durationInHours1 > 24, 'bond length is too short');
    require(intrestYearly1 > 2 && intrestYearly1 < 15, 'intrest is not in this range: (2 to 15)%');
    
    collatralToken = collatralToken1;
    borrowingToken = borrowingToken1;
    collatralAmount = collatralAmount1;
    borrowingAmount = borrowingAmount1;
    durationInHours = durationInHours1;
    intrestYearly = intrestYearly1;
    borrower = borrower1;
    lender = lender1;
    owner = msg.sender;
    
    borrowed = 0;
    liquidated = false;
  }

  //receive() external payable {}

  function getData() public view returns (getDataResponse memory) {
    return getDataResponse(borrower, lender, collatralToken, borrowingToken, collatralAmount, borrowingAmount, durationInHours, intrestYearly);
  }

  function liquidate() public {
    require(msg.sender == owner || msg.sender == borrower, 'you are not authorized to this action');
    liquidated = true;
    IERC20 tokenContract = IERC20(borrowingToken);
    BondManager bondManager = BondManager(owner);
    address addr = bondManager.getAddressOfLenderContract(lender);
    bool status = tokenContract.transfer(addr, tokenContract.balanceOf(address(this)));
    require(status, 'transfer failed');
  }

  function withdrawBorrowedTokens(uint amount) public {
    require(msg.sender == borrower, 'you are not the borrower');
    require(borrowed + amount <= borrowingAmount, 'not enough balance');
    borrowed += amount;
    emit Withdraw(borrower, amount);
    IERC20 tokenContract = IERC20(borrowingToken);
    bool status = tokenContract.transfer(borrower, amount);
    require(status, 'withdraw failed');
  }

  function depositBorrowedTokens(uint amount) public {
    // this can be called by anywone, for users with bots that want them to pay off debts.
    require(borrowed - amount > 0, 'you are sending too much tokens');
    borrowed -= amount;
    emit Deposit(msg.sender, borrower, amount);
    IERC20 tokenContract = IERC20(borrowingToken);
    require(tokenContract.allowance(msg.sender, address(this)) >= amount, 'allowance is not high enough');
    bool status = tokenContract.transferFrom(msg.sender, address(this), amount);
    require(status, 'deposit failed');
  }
}
