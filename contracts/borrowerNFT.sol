// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './bondManagerUtils/bondContractsManager.sol';
import './shared.sol';

contract BorrowerNFTManager is ERC721Burnable, Ownable, NFTManagerInterface {
  mapping(uint => Borrower) public borrowerContracts;
  mapping(uint => bool) burned;
  uint256 totalNFTs;

  constructor() ERC721("bond NFT borrower", "BNFTB") Ownable(msg.sender) {}

  function getNextId() public returns (uint) {
    for(uint i = 0; i < totalNFTs; i++) {
      if(burned[i]) {
        return i;
      }
    }
    return totalNFTs++;
  }

  function getOwner(uint id) public view returns (address) {
    return ownerOf(id);
  }

  function getContractAddress(uint id) public view returns (address payable) {
    return payable(address(borrowerContracts[id]));
  }

  function getIds(address borrower) public view returns (uint[] memory) {
    uint[] memory possibleIds = new uint[](totalNFTs);
    uint index = 0;

    for(uint i = 0; i < totalNFTs; i++) {
      if(ownerOf(i) == borrower) {
        possibleIds[index] = i;
        index++;
      }
    }

    uint[] memory res = new uint[](index);
    for(uint i = 0; i < index; i++) {
      res[i] = possibleIds[i];
    }

    return res;
  }

  function createBorrowerCotract(address lenderNFTManager, address priceOracleManager, uint borrowerId, uint lenderId, uint borrowedAmount, bondRequest memory request) public onlyOwner {
    borrowerContracts[borrowerId] = new Borrower(
      lenderNFTManager,
      address(this),
      owner(),
      priceOracleManager,
      borrowerId,
      lenderId,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      borrowedAmount,
      request.durationInHours,
      request.intrestYearly
    );

    _safeMint(request.borrower, borrowerId);
    burned[borrowerId] = false;
  }

  function burnBorrowerContract(uint id) public onlyOwner {
    _burn(id);
    burned[id] = true;
    delete borrowerContracts[id];
  }
} 

contract Borrower is Bond, HandlesETH {
  constructor(address _lenderNFTManager, address _borrowerNFTManager, address _bondContractsManager, address _priceOracleManager, uint _borrowerId, uint _lenderId, address _collatralToken, address _borrowingToken, uint _borrowingAmount, uint _collatralAmount, uint _durationInHours, uint _intrestYearly) 
  Bond(_lenderNFTManager, _borrowerNFTManager, _bondContractsManager, _priceOracleManager, _borrowerId, _lenderId, _collatralToken, _borrowingToken, _collatralAmount, _borrowingAmount, _durationInHours, _intrestYearly) {}
  
  receive() external payable {}

  event Withdraw(address borrower, uint amount);
  event Deposit(address sender, address borrower, uint amount);

  function liquidate(address lenderContract) public {
    require(msg.sender == owner || msg.sender == borrowerNFTManager.getOwner(borrowerId), 'you are not authorized to this action');
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
    require(msg.sender == borrowerNFTManager.getOwner(borrowerId), 'you are not the borrower');
    require(borrowed + amount <= borrowingAmount, 'not enough balance');
    borrowed += amount;
    emit Withdraw(borrowerNFTManager.getOwner(borrowerId), amount);
    IERC20 tokenContract = IERC20(borrowingToken);
    bool status = tokenContract.transfer(borrowerNFTManager.getOwner(borrowerId), amount);
    require(status, 'withdraw failed');
  }

  function withdrawBorrowedETH(uint amount) public {
    require(msg.sender == borrowerNFTManager.getOwner(borrowerId), 'you are not the borrower');
    require(borrowed + amount <= borrowingAmount, 'not enough balance');
    borrowed += amount;
    emit Withdraw(borrowerNFTManager.getOwner(borrowerId), amount);
    sendETHToBorrower(amount); 
  }

  function depositBorrowedETH() public payable {
    // this can be called by anywone, for users with bots that want them to pay off debts.
    require(msg.value <= borrowed, 'you are sending too much ETH');
    borrowed -= msg.value;
    emit Deposit(msg.sender, borrowerNFTManager.getOwner(borrowerId), msg.value);
  }

  function depositBorrowedTokens(uint amount) public {
    // this can be called by anywone, for users with bots that want them to pay off debts.
    require(amount <= borrowed, 'you are sending too much tokens');
    borrowed -= amount;
    emit Deposit(msg.sender, borrowerNFTManager.getOwner(borrowerId), amount);
    IERC20 tokenContract = IERC20(borrowingToken);
    require(tokenContract.allowance(msg.sender, address(this)) >= amount, 'allowance is not high enough');
    bool status = tokenContract.transferFrom(msg.sender, address(this), amount);
    require(status, 'deposit failed');
  }
}
