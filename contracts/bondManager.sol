// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
// import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

// import 'hardhat/console.sol';
import './borrowerNFT.sol';
import './lenderNFT.sol';
import './shared.sol';

struct bondRequest {
  address borrower;
  address collatralToken;
  uint256 collatralAmount;
  address borrowingtoken;
  uint256 borrowingAmount;
  uint256 durationInHours;
  uint256 intrestYearly;
}

contract BondManager {
  bondRequest[] bondRequests;
  // correction: the address in these mappings will be replaced with the index of the NFT that represents the borrower and lender contract respectively
  mapping(address => Borrower) public borrowerContracts;
  mapping(address => Lender) public lenderContracts;

  address[] whitelistedTokens;

  constructor() {
    whitelistedTokens = new address[](9);
    whitelistedTokens[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;// wrapped ETH
    whitelistedTokens[1] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;// USDT
    whitelistedTokens[2] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;// bridged USDC
    whitelistedTokens[3] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;// USDC
    whitelistedTokens[4] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;// wrapped BTC
    whitelistedTokens[5] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;// DAI
    whitelistedTokens[6] = 0x912CE59144191C1204E64559FE8253a0e49E6548;// ARB
    whitelistedTokens[7] = 0x680447595e8b7b3Aa1B43beB9f6098C79ac2Ab3f;// USDD
    whitelistedTokens[8] = 0x4D15a3A2286D883AF0AA1B3f21367843FAc63E07;// TUSD
  }

  function isWhitelistedToken(address token) internal view returns (bool) {
    bool res = false;
    uint len = whitelistedTokens.length; 
    for(uint i = 0; i < len; i++) {
      if(token == whitelistedTokens[i]) {
        res = true;
      }
    }
    return res;
  }

  function sendViaCall(address payable to, uint value) public payable {
    require(to != payable(address(0)), 'cant send to the 0 address');
    require(value != 0, 'can not send nothing');
    (bool sent, bytes memory data) = to.call{value: value}('');
    data = data; // this is just here to tell solc that it is being used
    require(sent, 'Failed to send Ether');
  }

  function deleteBondRequest(uint index) internal {
    if (index >= bondRequests.length) return;

    for (uint i = index; i<bondRequests.length-1; i++){
      bondRequests[i] = bondRequests[i+1];
    }
    bondRequests.pop();
  }
  
  function postETHToTokenbondRequest(address borrowingToken, uint borrowingAmount, uint termInHours, uint intrestYearly) public payable returns (bool) {
    require(msg.value != 0, 'cant post a bond with no collatral');
    require(isWhitelistedToken(borrowingToken), 'this token is not whitelisted');
    require(borrowingAmount != 0, 'cant borrow nothing');
    require(termInHours > 24, 'bond length is too short');
    require(intrestYearly > 2 && intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');
    
    bondRequest memory newRequest = bondRequest(msg.sender, address(1), msg.value, borrowingToken, borrowingAmount, termInHours, intrestYearly);
    bondRequests.push(newRequest);

    return true;
  }

  function postTokenToTokenbondRequest(address collatralToken, uint collatralAmount, address borrowingToken, uint borrowingAmount, uint termInHours, uint intrestYearly) public returns (bool) {
    require(collatralAmount != 0, 'cant post a bond with no collatral');
    require(isWhitelistedToken(borrowingToken), 'this token is not whitelisted');
    require(borrowingAmount != 0, 'cant borrow nothing');
    require(termInHours > 24, 'bond length is too short');
    require(intrestYearly > 2 && intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');

    IERC20 collatralTokenContract = IERC20(collatralToken);
    uint allowance = collatralTokenContract.allowance(msg.sender, address(this));
    require(allowance >= collatralAmount, 'allowance is not high ehough');

    bondRequest memory newRequest = bondRequest(msg.sender, collatralToken, collatralAmount, borrowingToken, borrowingAmount, termInHours, intrestYearly);
    bondRequests.push(newRequest);   

    bool status = collatralTokenContract.transferFrom(msg.sender, address(this), collatralAmount);
    require(status, 'transferFrom failed');
    return true;
  }

  function getAddressOfBorrowerContract(address borrower) public view returns (address) {
    return address(borrowerContracts[borrower]);
  }

  function getAddressOfLenderContract(address lender) public view returns (address) {
    return address(lenderContracts[lender]);
  }

  function liquifyFromBorrower(address borrower, address lender) public {
    require(msg.sender == address(borrowerContracts[borrower]), 'you are not authorized to do this action');
    
    getDataResponse memory res = lenderContracts[borrower].getData();
    require(res.borrower == borrower, 'the lender does not have this address as the borrower');
    lenderContracts[lender].setLiquidation();
  }

  function indexOfBondRequest(bondRequest memory request) internal view returns (int) {
    int index = -1;
    uint len = bondRequests.length; 

    for (uint i = 0; i < len; i++) {
      bool isMatching = (
        (bondRequests[i].borrower == request.borrower) &&
        (bondRequests[i].collatralToken == request.collatralToken) &&
        (bondRequests[i].collatralAmount == request.collatralAmount) &&
        (bondRequests[i].borrowingtoken == request.borrowingtoken) &&
        (bondRequests[i].durationInHours == request.durationInHours) &&
        (bondRequests[i].intrestYearly == request.intrestYearly)
      );
      if (isMatching) {
        index = int(i);
      }
    }
    return index;
  }

  function cancelETHToTokenBondRequest(bondRequest memory request) public returns (bool) {
    int index = indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    require(bondRequests[uint(index)].borrower == msg.sender, 'not the borrower');
    uint amount = bondRequests[uint(index)].collatralAmount;
    deleteBondRequest(uint(index));
    sendViaCall(payable(request.borrower), amount);
    return true;
  }

  function cancelTokenToTokenBondRequest(bondRequest memory request) public payable returns (bool) {
    int index = indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    require(bondRequests[uint(index)].borrower == msg.sender, 'not the borrower');
    uint amount = bondRequests[uint(index)].collatralAmount;
    address token = bondRequests[uint(index)].collatralToken; 
    deleteBondRequest(uint(index));
    IERC20 tokenContract = IERC20(token);
    bool status = tokenContract.transfer(request.borrower, amount);
    require(status, 'tranfer from BondManager to msg.sender failed');
    return true;
  }

  function getBondRequests() public view returns (bondRequest[] memory) {
    return bondRequests; 
  }

  function lendToETHBorrower(bondRequest memory request) public payable {
    int index = indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address'); 

    lenderContracts[msg.sender] = new Lender(request.borrower, msg.sender, request.collatralToken, request.borrowingtoken, request.collatralAmount, request.borrowingAmount, request.durationInHours, request.intrestYearly);
    borrowerContracts[request.borrower] = new Borrower(request.borrower, msg.sender, request.collatralToken, request.borrowingtoken, request.collatralAmount, request.borrowingAmount, request.durationInHours, request.intrestYearly);

    deleteBondRequest(uint(index));

    IERC20 borrowingTokenContract = IERC20(request.borrowingtoken);
    uint allowance = borrowingTokenContract.allowance(msg.sender, address(this));
    require(allowance >= request.borrowingAmount, 'allowance is not high ehough');
    
    bool status1 = borrowingTokenContract.transferFrom(msg.sender, address(this), request.borrowingAmount);
    bool status2 = borrowingTokenContract.transfer(address(borrowerContracts[request.borrower]), request.borrowingAmount);
    require(address(this).balance >= request.collatralAmount, 'Contract does not have enough Ether');
    require(request.collatralAmount > 0, 'ETHAmount should be greater than zero');
    sendViaCall(payable(address(lenderContracts[msg.sender])), request.collatralAmount);
    require(status1 && status2, 'transferFrom failed');
  }

  function lendToTokenBorrower(bondRequest memory request) public {
    int index = indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');

    lenderContracts[msg.sender] = new Lender(request.borrower, msg.sender, request.collatralToken, request.borrowingtoken, request.collatralAmount, request.borrowingAmount, request.durationInHours, request.intrestYearly);
    borrowerContracts[request.borrower] = new Borrower(request.borrower, msg.sender, request.collatralToken, request.borrowingtoken, request.collatralAmount, request.borrowingAmount, request.durationInHours, request.intrestYearly);
    deleteBondRequest(uint(index));

    IERC20 borrowingTokenContract = IERC20(request.borrowingtoken);
    IERC20 collatralTokenContract = IERC20(request.collatralToken);
    uint allowance = borrowingTokenContract.allowance(msg.sender, address(this));
    require(allowance >= request.borrowingAmount, 'allowance is not high ehough');
    
    bool status1 = borrowingTokenContract.transferFrom(msg.sender, address(this), request.borrowingAmount);
    bool status2 = borrowingTokenContract.transfer(address(borrowerContracts[request.borrower]), request.borrowingAmount);
    bool status3 = collatralTokenContract.transfer(address(lenderContracts[msg.sender]), request.collatralAmount);
    require(status1 && status2 && status3, 'transferFrom failed');
  }
}
