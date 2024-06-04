// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './bondManager.sol';
import './shared.sol';

contract Borrower is Bond {

constructor(address borrower1, address lender1, address collatralToken1, address borrowingToken1, uint borrowingAmount1, uint collatralAmount1, uint durationInHours1, uint intrestYearly1) Bond(borrower1, lender1, collatralToken1, borrowingToken1, collatralAmount1, borrowingAmount1, durationInHours1, intrestYearly1) {}


  event Withdraw(address borrower, uint amount);
  event Deposit(address sender, address borrower, uint amount);

  receive() external payable {}

  function liquidate() public {
    require(msg.sender == owner || msg.sender == borrower, 'you are not authorized to this action');
    liquidated = true;
    IERC20 tokenContract = IERC20(borrowingToken);
    BondManager bondManager = BondManager(owner);
    address addr = bondManager.getAddressOfLenderContract(lender);
    bool status = tokenContract.transfer(addr, tokenContract.balanceOf(address(this)));
    require(status, 'transfer failed');
    BondManager(owner).liquifyFromBorrower(borrower, lender);
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

  function withdrawBorrowedETH(uint amount) public {
    require(msg.sender == borrower, 'you are not the borrower');
    require(borrowed + amount <= borrowingAmount, 'not enough balance');
    borrowed += amount;
    emit Withdraw(borrower, amount);
    sendETHToBorrower(amount); 
  }

  function depositBorrowedETH() public payable {
    // this can be called by anywone, for users with bots that want them to pay off debts.
    require(borrowed - msg.value > 0, 'you are sending too much ETH');
    borrowed -= msg.value;
    emit Deposit(msg.sender, borrower, msg.value);
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
