// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

//import './bondManagerUtils/requestManager.sol';
import './bondManagerUtils/bondContractsManager.sol';
import './TestingHelper.sol';
import './shared.sol';

contract LenderNFTManager is ERC721Burnable, Ownable, NFTManagerInterface {
  Lender internal lenderContract;
  mapping(uint32 => bool) internal burned;
  uint32 internal totalNFTs;

  constructor() ERC721("bond NFT lender", "BNFTL") Ownable(msg.sender) {}

  function setAddress(address borrowerNFTManager, address priceOracleManager, address testingHelper) public onlyOwner {
    lenderContract = new Lender(address(this), borrowerNFTManager, msg.sender, priceOracleManager, testingHelper);
  }

  function getNextId() public onlyOwner returns (uint32) {
    uint32 total = totalNFTs;
    for(uint32 i = 0; i < total; i++) {
      if(burned[i]) {
        return i;
      }
    }
    return totalNFTs++;
  }

  function getOwner(uint32 id) public view returns (address) {
    return ownerOf(id);
  }

  function getContractAddress() public view returns (address payable) {
    return payable(address(lenderContract));
  }

  function getIds(address lender) public view returns (uint32[] memory res) {
    uint32 total = totalNFTs;
    uint32[] memory possibleIds = new uint32[](total);
    uint32 index = 0;

    for(uint32 i; i < total; i++) {
      if(ownerOf(i) == lender) {
        possibleIds[index] = i;
        index++;
      }
    }

    res = new uint32[](index);
    for(uint32 i; i < index; i++) {
      res[i] = possibleIds[i];
    }
  }

  function createLenderNFT(address lender, uint32 bondId, uint32 lenderId) public onlyOwner {
    lenderContract.setBondId(bondId, lenderId); 
    _safeMint(lender, lenderId);
    burned[lenderId] = false;
  }

  function burnLenderContract(uint32 id) public onlyOwner {
    _burn(id);
    burned[id] = true;
  }
}

contract Lender is Bond, ReentrancyGuard {
  constructor(address _lenderNFTManager, address _borrowerNFTManager, address _bondContractsManager, address _priceOracleManager, address _testingHelper) Bond(_lenderNFTManager, _borrowerNFTManager, _bondContractsManager, _priceOracleManager, _testingHelper) {}

  receive() external payable {}
  
  function liquidate(uint32 id) public nonReentrant {
    bondData memory data = getBondData(id);
    require(msg.sender == address(owner), 'you are not authorized to do this action');
    data.liquidated = true;
    _liquidate(id, data);
  }

  function _liquidate(uint32 id, bondData memory data) internal {
    uint amountOwed = data.borrowed;
    IERC20 collatralTokenContract = IERC20(data.collatralToken);// when eth is the collatral, this will not be functional so it will not be used
    IERC20 borrowingTokenContract = IERC20(data.borrowingToken);// when eth is borrowed, this will not be functional so it will not be used
    data.total = getOwed(id);
    setBondData(id, data);
    if (data.collatralToken == address(1)) {
      _handleEth(id, data, amountOwed);
    } else {
      _handleToken(data, amountOwed, collatralTokenContract, borrowingTokenContract);
    }
  }

  function _handleEth(uint32 id, bondData memory data, uint amountOwed) internal {
    uint spentAmount = address(this).balance;
    if(amountOwed != 0) {
      uint tmp = helper.getAmountIn(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, data.borrowingToken, amountOwed);
      // slither-disable-next-line arbitrary-send-eth
      tmp = helper.swapETHforToken{value: tmp}(data.borrowingToken);
      require(tmp >= amountOwed, 'swap did not result in enough tokens');
    }
    spentAmount -= address(this).balance;
    
    sendETHToBorrower(id, data.collatralAmount - spentAmount);
  }

  function _handleToken(bondData memory data, uint amountOwed, IERC20 collatralTokenContract, IERC20 borrowingTokenContract) internal {
    uint spentAmount = collatralTokenContract.balanceOf(address(this));
    if(amountOwed != 0) {
      uint tmp = helper.getAmountIn(data.collatralToken, ((data.borrowingToken == address(1)) ? 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 : data.borrowingToken), amountOwed);
      bool status = collatralTokenContract.approve(address(helper), tmp * 10);
      require(status, 'approve failed');

      if(data.borrowingToken != address(1)) {
        uint res = helper.swapTokenForToken(data.collatralToken, data.borrowingToken, tmp);
        require(res >= amountOwed, 'did not get required tokens from dex');
      } else {
        uint res = helper.swapTokenForETH(data.collatralToken, tmp);
        require(res >= amountOwed, 'did not get required tokens from dex');
      }
    }
    spentAmount -= collatralTokenContract.balanceOf(address(this));
    
    if(data.borrowingToken != address(1)) {
      require(borrowingTokenContract.balanceOf(address(this)) >= data.borrowingAmount, 'swap did not result in enough tokens');
      bool status = collatralTokenContract.transfer(borrowerNFTManager.getOwner(data.borrowerId), data.collatralAmount - spentAmount);
      require(status, 'transfer failed');
    } else {
      bool status = collatralTokenContract.transfer(borrowerNFTManager.getOwner(data.borrowerId), data.collatralAmount - spentAmount);
      require(status, 'transfer failed');
    }
  }
  
  // these functions should be accessible by the nft holder but the selector cant be found for any of the functions in this contract so i have to route them through the bond contracts manager right now
  function withdraw(address lender, uint32 id) public {
    require(msg.sender == address(owner), 'currently need to route this function through the bondContractsManager (very weird bug)');
    bondData memory data = getBondData(id);
    require(lender == lenderNFTManager.getOwner(id), 'you are not the lender');
    require(data.liquidated, 'this bond has not yet been liquidated');

    if(data.borrowingToken != address(1)) {
      IERC20 tokenContract = IERC20(data.borrowingToken);
      bool status = tokenContract.transfer(lender, data.total);
      require(status, "Withdraw failed");
    } else {
      sendETHToLender(id, data.total);
    }

    BondContractsManager burn = BondContractsManager(owner);
    burn.burnFromLender(id);
  }
}
