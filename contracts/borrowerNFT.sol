// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './bondManagerUtils/bondContractsManager.sol';
import './shared.sol';

contract Borrower is Bond {
  constructor(address borrower1, address lender1, address collatralToken1, address borrowingToken1, uint borrowingAmount1, uint collatralAmount1, uint durationInHours1, uint intrestYearly1) Bond(borrower1, lender1, collatralToken1, borrowingToken1, collatralAmount1, borrowingAmount1, durationInHours1, intrestYearly1) {}

  event Withdraw(address borrower, uint amount);
  event Deposit(address sender, address borrower, uint amount);

  receive() external payable {}
  
  // slither-disable-start low-level-calls
  // slither-disable-start arbitrary-send-eth 
  function sendViaCall(address payable to, uint value) internal {
    require(to != payable(address(0)), 'cant send to the 0 address');
    require(value != 0, 'can not send nothing');
    (bool sent,) = to.call{value: value}('');
    require(sent, 'Failed to send Ether');
  }
  // slither-disable-end low-level-calls
  // slither-disable-end arbitrary-send-eth

  function liquidate(address lenderContract) public {
    require(msg.sender == owner || msg.sender == borrower, 'you are not authorized to this action');
    liquidated = true;
    if(borrowingToken != address(1)) {
      IERC20 tokenContract = IERC20(borrowingToken);
      bool status = tokenContract.transfer(lenderContract, tokenContract.balanceOf(address(this)));
      require(status, 'transfer failed');
    } else {
      sendViaCall(payable(lenderContract), address(this).balance);
    }
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
    require(msg.value <= borrowed, 'you are sending too much ETH');
    borrowed -= msg.value;
    emit Deposit(msg.sender, borrower, msg.value);
  }

  function depositBorrowedTokens(uint amount) public {
    // this can be called by anywone, for users with bots that want them to pay off debts.
    require(amount <= borrowed, 'you are sending too much tokens');
    borrowed -= amount;
    emit Deposit(msg.sender, borrower, amount);
    IERC20 tokenContract = IERC20(borrowingToken);
    require(tokenContract.allowance(msg.sender, address(this)) >= amount, 'allowance is not high enough');
    bool status = tokenContract.transferFrom(msg.sender, address(this), amount);
    require(status, 'deposit failed');
  }
}
