// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

import './TestingHelper.sol';
import './shared.sol';

contract Lender is Bond, ReentrancyGuard {
  constructor(address borrower1, address lender1, address collatralToken1, address borrowingToken1, uint borrowingAmount1, uint collatralAmount1, uint durationInHours1, uint intrestYearly1) Bond(borrower1, lender1, collatralToken1, borrowingToken1, collatralAmount1, borrowingAmount1, durationInHours1, intrestYearly1) {}

  receive() external payable {}

  function liquidate() public nonReentrant {
    require(msg.sender == owner, 'you are not authorized to do this action');
    liquidated = true;
    _liquidate();
  }

  function _liquidate() internal {
    uint amountOwed = 0;
    IERC20 borrowingTokenContract = IERC20(borrowingToken);// when eth is the token borrowed, this will not be functional so it will not be used 
    if(borrowingToken != address(1)) {
      amountOwed = borrowingAmount - borrowingTokenContract.balanceOf(address(this));
    } else {
      amountOwed = borrowingAmount - address(this).balance;
    }

    TestingHelper helper = new TestingHelper();
    if (collatralToken == address(1)) {
      _handleEth(helper, amountOwed, borrowingTokenContract);
    } else {
      _handleToken(helper, amountOwed, borrowingTokenContract);
    }
  }

  function _handleEth(TestingHelper helper, uint amountOwed, IERC20 borrowingTokenContract) internal {
    if(amountOwed != 0) {
      uint tmp = helper.getAmountIn(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, borrowingToken, amountOwed);
      tmp = helper.swapETHforToken{value: tmp}(borrowingToken);
      require(borrowingTokenContract.balanceOf(address(this)) >= borrowingAmount, 'swap did not result in enough tokens');
    }
    
    bool status = borrowingTokenContract.transfer(lender, borrowingAmount);
    sendETHToBorrower(address(this).balance);
    require(status, 'transfer failed');
  }

  function _handleToken(TestingHelper helper, uint amountOwed, IERC20 borrowingTokenContract) internal {
    IERC20 collatralTokenContract = IERC20(collatralToken);
    if(amountOwed != 0) {
      uint tmp = helper.getAmountIn(collatralToken, ((borrowingToken == address(1)) ? 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 : borrowingToken), amountOwed);
      bool status = collatralTokenContract.approve(address(helper), tmp);
      require(status, 'approve failed');

      if(borrowingToken != address(1)) {
        uint res = helper.swapTokenForToken(collatralToken, borrowingToken, tmp);
        require(res >= amountOwed, 'did not get required tokens from dex');
      } else {
        uint res = helper.swapTokenForETH(collatralToken, tmp);
        require(res >= amountOwed, 'did not get required tokens from dex');
        require(address(this).balance >= borrowingAmount, 'swap did not result in enough tokens');
      }
    }
    
    if(borrowingToken != address(1)) {
      require(borrowingTokenContract.balanceOf(address(this)) >= borrowingAmount, 'swap did not result in enough tokens');
      bool status1 = borrowingTokenContract.transfer(lender, borrowingAmount);
      bool status2 = collatralTokenContract.transfer(borrower, collatralTokenContract.balanceOf(address(this)));
      require(status1 && status2, 'transfer failed');
    } else {
      sendETHToLender(borrowingAmount);
      bool status = collatralTokenContract.transfer(borrower, collatralTokenContract.balanceOf(address(this)));
      require(status, 'transfer failed');
    }
  }

  function withdawLentTokens() public {
    require(msg.sender == lender, 'you are not the lender');
    require(liquidated, 'this bond has not yet been liquidated');

    IERC20 tokenContract = IERC20(borrowingToken);
    bool status = tokenContract.transfer(lender, tokenContract.balanceOf(address(this)));
    require(status, 'withdraw failed');
  }
}
