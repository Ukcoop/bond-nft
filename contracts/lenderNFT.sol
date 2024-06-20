// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

import './bondManagerUtils/requestManager.sol';
import './bondManagerUtils/bondContractsManager.sol';
import './TestingHelper.sol';
import './shared.sol';

contract LenderNFTManager is ERC721Burnable, Ownable, NFTManagerInterface {
  mapping(uint => Lender) lenderContracts;
  mapping(uint => bool) burned;
  uint256 totalNFTs;

  constructor() ERC721("bond NFT lender", "BNFTL") Ownable(msg.sender) {}

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
    return payable(address(lenderContracts[id]));
  }

  function getIds(address lender) public view returns (uint[] memory) {
    uint[] memory possibleIds = new uint[](totalNFTs);
    uint index = 0;

    for(uint i = 0; i < totalNFTs; i++) {
      if(ownerOf(i) == lender) {
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

  function createLenderContract(address borrowerNFTManager, address priceOracleManager, address lender, uint borrowerId, uint lenderId, uint borrowedAmount, bondRequest memory request) public onlyOwner {
    lenderContracts[lenderId] = new Lender(
      address(this),
      borrowerNFTManager,
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

    _safeMint(lender, lenderId);
    burned[lenderId] = false;
  }

  function burnLenderContract(uint id) public onlyOwner {
    _burn(id);
    burned[id] = true;
    delete lenderContracts[id];
  }
}

contract Lender is Bond, ReentrancyGuard {
  constructor(address _lenderNFTManager, address _borrowerNFTManager, address _bondContractsManager, address _priceOracleManager, uint _borrowerId, uint _lenderId, address _collatralToken, address _borrowingToken, uint _borrowingAmount, uint _collatralAmount, uint _durationInHours, uint _intrestYearly) 
  Bond(_lenderNFTManager, _borrowerNFTManager, _bondContractsManager, _priceOracleManager, _borrowerId, _lenderId, _collatralToken, _borrowingToken, _collatralAmount, _borrowingAmount, _durationInHours, _intrestYearly) {}

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
    
    sendETHToBorrower(address(this).balance);
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
      bool status = collatralTokenContract.transfer(borrowerNFTManager.getOwner(borrowerId), collatralTokenContract.balanceOf(address(this)));
      require(status, 'transfer failed');
    } else {
      bool status = collatralTokenContract.transfer(borrowerNFTManager.getOwner(borrowerId), collatralTokenContract.balanceOf(address(this)));
      require(status, 'transfer failed');
    }
  }

  function withdawLentTokens() public {
    require(msg.sender == lenderNFTManager.getOwner(lenderId), 'you are not the lender');
    require(liquidated, 'this bond has not yet been liquidated');

    IERC20 tokenContract = IERC20(borrowingToken);
    BondContractsManager burn = BondContractsManager(owner);
    bool status = tokenContract.transfer(lenderNFTManager.getOwner(lenderId), tokenContract.balanceOf(address(this)));
    require(status, 'withdraw failed');
    burn.burnFromLender(lenderId);
  }

  function withdrawLentETH() public {
    require(msg.sender == lenderNFTManager.getOwner(lenderId), 'you are not the lender');
    require(liquidated, 'this bond has not yet been liquidated');

    BondContractsManager burn = BondContractsManager(owner);
    sendETHToLender(borrowingAmount);
    burn.burnFromLender(lenderId);
  }
}
