// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct bondRequest {
  address borrower;
  address collatralToken;
  uint256 collatralAmount;
  address borrowingtoken;
  uint256 borrowingAmount;
  uint256 durationInHours;
  uint256 intrestYearly;
}

contract RequestManager {
  address[] public whitelistedTokens;
  bondRequest[] bondRequests;
  address immutable deployer;
  address bondManagerAddress;
  address bondContractsManagerAddress;
  
  constructor() {
    whitelistedTokens = new address[](9);
    whitelistedTokens[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // wrapped ETH
    whitelistedTokens[1] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT
    whitelistedTokens[2] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // bridged USDC
    whitelistedTokens[3] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC
    whitelistedTokens[4] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; // wrapped BTC
    whitelistedTokens[5] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI
    whitelistedTokens[6] = 0x912CE59144191C1204E64559FE8253a0e49E6548; // ARB
    whitelistedTokens[7] = 0x680447595e8b7b3Aa1B43beB9f6098C79ac2Ab3f; // USDD
    whitelistedTokens[8] = 0x4D15a3A2286D883AF0AA1B3f21367843FAc63E07; // TUSD

    deployer = msg.sender;
    bondManagerAddress = address(0);
    bondContractsManagerAddress = address(0);
  }

  function isWhitelistedToken(address token) public view returns (bool) {
    uint len = whitelistedTokens.length; 
    for (uint i = 0; i < len; i++) {
      if (token == whitelistedTokens[i]) {
        return true;
      }
    }
    return false;
  }

  function transferFrom(
    address token,
    address from,
    uint amount
  ) internal returns (bool) {
    IERC20 tokenContract = IERC20(token);
    uint allowance = tokenContract.allowance(from, address(this));
    require(allowance >= amount, 'allowance is not high enough');
    //slither-disable-next-line arbitrary-send-erc20
    bool status = tokenContract.transferFrom(from, address(this), amount);
    return status;
  }

  function transfer(
    address token,
    address to,
    uint amount
  ) internal returns (bool) {
    IERC20 tokenContract = IERC20(token);
    return tokenContract.transfer(to, amount);
  }

  function setAddresses(address bondManager, address bondContractsManager) public {
    require(bondManager != address(0), 'bondManager address cant be address(0)');
    require(bondContractsManager != address(0), 'bondContractsManager address cant be address(0)');
    require(msg.sender == deployer, 'only the deployer can do this action');
    require(bondManagerAddress == address(0) && bondContractsManagerAddress == address(0), 'addresses allredy initialized');
    bondManagerAddress = bondManager;
    bondContractsManagerAddress = bondContractsManager;
  }

  function sendViaCall(address payable to, uint value) public payable {
    require(to != payable(address(0)), 'cant send to the 0 address');
    require(value != 0, 'can not send nothing');
    //slither-disable-next-line low-level-calls
    (bool sent,) = to.call{value: value}('');
    require(sent, 'Failed to send Ether');
  }

  function sendFromBondContractsManager(address payable to, uint value) public payable {
    require(msg.sender == bondContractsManagerAddress, 'you are not authorized to do this action');
    sendViaCall(to, value);
  }

  function sendTokenFromBondContractsManager(address token, address to, uint value) public returns (bool) {
    require(msg.sender == bondContractsManagerAddress, 'you are not authorized to do this action');
    bool status = transfer(token, to, value);
    return status;
  }

  function deleteBondRequest(uint index) public {
    require(msg.sender == bondManagerAddress || msg.sender == bondContractsManagerAddress, 'you are not authorized to do this action');
    if (index >= bondRequests.length) return;
    
    uint len = bondRequests.length; 
    for (uint i = index; i < len - 1; i++) {
      bondRequests[i] = bondRequests[i + 1];
    }
    bondRequests.pop();
  }

  function postETHToTokenbondRequest(
    address borrower,
    address borrowingToken,
    uint borrowingAmount,
    uint termInHours,
    uint intrestYearly
  ) public payable returns (bool) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    require(msg.value != 0, 'cant post a bond with no collatral');
    require(isWhitelistedToken(borrowingToken), 'this token is not whitelisted');
    require(borrowingAmount != 0, 'cant borrow nothing');
    require(termInHours > 24, 'bond length is too short');
    require(intrestYearly > 2 && intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');

    bondRequest memory newRequest = bondRequest(
      borrower,
      address(1),
      msg.value,
      borrowingToken,
      borrowingAmount,
      termInHours,
      intrestYearly
    );
    bondRequests.push(newRequest);
    return true;
  }

  function postTokenToETHBondRequest(
    address borrower,
    address collatralToken,
    uint collatralAmount,
    uint borrowingAmount,
    uint termInHours,
    uint intrestYearly
  ) public returns (bool) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    require(collatralAmount != 0, 'cant post a bond with no collatral');
    require(borrowingAmount != 0, 'cant borrow nothing');
    require(isWhitelistedToken(collatralToken), 'this token is not whitelisted');
    require(termInHours > 24, 'bond length is too short');
    require(intrestYearly > 2 && intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');

    bondRequest memory newRequest = bondRequest(
      borrower,
      collatralToken,
      collatralAmount,
      address(1),
      borrowingAmount,
      termInHours,
      intrestYearly
    );
    bondRequests.push(newRequest);
    bool status = transferFrom(collatralToken, borrower, collatralAmount);
    require(status, 'transferFrom failed');
    return true;
  }

  function postTokenToTokenbondRequest(
    address borrower,
    address collatralToken,
    uint collatralAmount,
    address borrowingToken,
    uint borrowingAmount,
    uint termInHours,
    uint intrestYearly
  ) public returns (bool) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    require(collatralAmount != 0, 'cant post a bond with no collatral');
    require(isWhitelistedToken(collatralToken), 'this token is not whitelisted');
    require(isWhitelistedToken(borrowingToken), 'this token is not whitelisted');
    require(borrowingAmount != 0, 'cant borrow nothing');
    require(termInHours > 24, 'bond length is too short');
    require(intrestYearly > 2 && intrestYearly < 15, 'intrest is not in this range: (2 to 15)%');

    bondRequest memory newRequest = bondRequest(
      borrower,
      collatralToken,
      collatralAmount,
      borrowingToken,
      borrowingAmount,
      termInHours,
      intrestYearly
    );
    bondRequests.push(newRequest);
    bool status = transferFrom(collatralToken, borrower, collatralAmount);
    require(status, 'transferFrom failed');
    return true;
  }

  function indexOfBondRequest(bondRequest memory request) public view returns (int) {
    require(msg.sender == bondManagerAddress || msg.sender == bondContractsManagerAddress, 'you are not authorized to do this action');
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
        return int(i);
      }
    }
    return -1;
  }

  function cancelETHToTokenBondRequest(address borrower, bondRequest memory request) public returns (bool) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    require(bondRequests[uint(index)].borrower == borrower, 'not the borrower');
    uint amount = bondRequests[uint(index)].collatralAmount;
    deleteBondRequest(uint(index));
    sendViaCall(payable(request.borrower), amount);
    return true;
  }

  function cancelTokenToTokenBondRequest(address borrower, bondRequest memory request) public payable returns (bool) {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    require(bondRequests[uint(index)].borrower == borrower, 'not the borrower');
    uint amount = bondRequests[uint(index)].collatralAmount;
    address token = bondRequests[uint(index)].collatralToken;
    deleteBondRequest(uint(index));
    bool status = transfer(token, request.borrower, amount);
    require(status, 'transfer from BondManager to msg.sender failed');
    return true;
  }

  function getBondRequests() public view returns (bondRequest[] memory) {
    return bondRequests;
  }

}
