// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import './TestingHelper.sol';

contract Lender is ReentrancyGuard {
  address immutable borrower;
  address immutable lender;
  address immutable owner;
  address immutable collatralToken; // this will be address(1) for native eth
  address immutable borrowingToken;
  uint256 immutable borrowingAmount;
  uint256 immutable durationInHours;
  uint256 immutable intrestYearly;
  bool liquidated;

  constructor(address borrower1, address lender1, address collatralToken1, address borrowingToken1, uint256 borrowingAmount1, uint durationInHours1, uint intrestYearly1) {
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
    durationInHours = durationInHours1;
    intrestYearly = intrestYearly1;
    liquidated = false;
  }

  function sendETHToBorrower(uint value) internal {
    require(value != 0, 'can not send nothing');
    //slither-disable-next-line arbitrary-send-eth
    (bool sent, bytes memory data) = payable(borrower).call{value: value}("");// since the borrower variable is immutable and only set by the bondManager, this is a false positive
    data = data; // this is just here to tell solc that it is being used
    require(sent, "Failed to send Ether");
  }

  receive() external payable {}
  
  function setLiquidation() public nonReentrant {
    // this is commented out for testing right now, the system that would call this it not made yet
    //require(msg.sender == owner, 'you are not authorized to do this action');
    liquidated = true;
    _liquidate();
  }

  function _liquidate() internal {
    IERC20 borrowingTokenContract = IERC20(borrowingToken); 
    uint amountOwed = borrowingAmount - borrowingTokenContract.balanceOf(address(this));

    if (amountOwed != 0) {
      TestingHelper helper = new TestingHelper();
      if (collatralToken == address(1)) {
        _handleEth(helper, amountOwed, borrowingTokenContract);
      } else {
        _handleToken(helper, amountOwed, borrowingTokenContract);
      }
    }
  }

  function _handleEth(TestingHelper helper, uint amountOwed, IERC20 borrowingTokenContract) internal {
    uint tmp = helper.getAmountIn(borrowingToken, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, amountOwed);
    tmp = helper.swapETHforToken{value: tmp}(borrowingToken);

    require(borrowingTokenContract.balanceOf(address(this)) >= borrowingAmount, 'swap did not result in enough tokens');
    sendETHToBorrower(address(this).balance);
  }

  function _handleToken(TestingHelper helper, uint amountOwed, IERC20 borrowingTokenContract) internal {
    IERC20 collatralTokenContract = IERC20(collatralToken);
    uint tmp = helper.getAmountIn(borrowingToken, collatralToken, amountOwed);

    bool status = collatralTokenContract.approve(address(helper), tmp);
    require(status, 'approve failed');
    
    uint res = helper.swapTokenForToken(collatralToken, borrowingToken, tmp);
        
    require(borrowingTokenContract.balanceOf(address(this)) >= borrowingAmount, 'swap did not result in enough tokens');
        
    status = collatralTokenContract.transfer(borrower, collatralTokenContract.balanceOf(address(this)));
    require(status, 'transfer failed');
  }

  function withdawLentTokens() public {
    require(msg.sender == lender, 'you are not the lender');
    require(liquidated, 'this bond has not yet been liquidated');

    IERC20 tokenContract = IERC20(borrowingToken);
    bool status = tokenContract.transfer(lender, tokenContract.balanceOf(address(this)));
    require(status, 'withdraw failed');
  }
}
