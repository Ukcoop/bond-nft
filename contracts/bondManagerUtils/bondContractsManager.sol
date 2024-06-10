// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import '../borrowerNFT.sol';
import '../lenderNFT.sol';
import './requestManager.sol';

contract BondContractsManager {
  mapping(address => Borrower) public borrowerContracts;
  mapping(address => Lender) public lenderContracts;
  RequestManager immutable requestManager;
  address immutable deployer;
  address bondManagerAddress;
  
  constructor(address _requestManager) {
    requestManager = RequestManager(_requestManager);
    deployer = msg.sender;
  }
  
  //slither-disable-next-line naming-convention
  function setAddress(address _bondManagerAddress) public {
    require(_bondManagerAddress != address(0), 'bondManagerAddress can not be address(0)');
    require(msg.sender == deployer, 'only the deployer can do this action');
    require(bondManagerAddress == address(0), 'bondManagerAddress allredy initialized');
    bondManagerAddress = _bondManagerAddress;
  }

  // slither-disable-start low-level-calls
  // slither-disable-start arbitrary-send-eth 
  function sendViaCall(address payable to, uint value) internal {
    require(to != payable(address(0)), 'cant send to the 0 address');
    require(value != 0, 'can not send nothing');
    (bool sent,) = to.call{value: value}('');
    require(sent, 'Failed to send Ether...');
  }
  // slither-disable-end low-level-calls
  // slither-disable-end arbitrary-send-eth

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
  
  function liquidate(address borrower, address lender) public {
    require(msg.sender == address(borrowerContracts[borrower]) || msg.sender == bondManagerAddress, 'you are not authorized to do this action');
    getDataResponse memory res = lenderContracts[lender].getData();
    require(res.borrower == borrower, 'the lender does not have this address as the borrower');
    borrowerContracts[borrower].liquidate(address(lenderContracts[lender]));
    lenderContracts[lender].liquidate();
    delete borrowerContracts[borrower]; 
    delete lenderContracts[lender]; 
  }

  function getAddressOfBorrowerContract(address borrower) public view returns (address) {
    return address(borrowerContracts[borrower]);
  }

  function getAddressOfLenderContract(address lender) public view returns (address) {
    return address(lenderContracts[lender]);
  }

  function lendToETHToTokenBorrower(address lender, bondRequest memory request) public payable {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');

    lenderContracts[lender] = new Lender(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );
    borrowerContracts[request.borrower] = new Borrower(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );

    requestManager.deleteBondRequest(uint(index));

    bool status1 = transferFrom(request.borrowingtoken, lender, request.borrowingAmount);
    bool status2 = transfer(request.borrowingtoken, address(borrowerContracts[request.borrower]), request.borrowingAmount);
    require(status1 && status2, 'transferFrom failed');
    require(address(requestManager).balance >= request.collatralAmount, 'Contract does not have enough Ether');
    require(request.collatralAmount > 0, 'ETHAmount should be greater than zero');
    requestManager.sendFromBondContractsManager(payable(address(lenderContracts[lender])), request.collatralAmount);
  }

  function lendToTokenToETHBorrower(address lender, bondRequest memory request) public payable {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');
    require(msg.value >= request.borrowingAmount, 'not enough ETH was sent');

    lenderContracts[lender] = new Lender(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );
    borrowerContracts[request.borrower] = new Borrower(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );
    requestManager.deleteBondRequest(uint(index));

    sendViaCall(payable(address(borrowerContracts[request.borrower])), request.borrowingAmount);
    bool status = requestManager.sendTokenFromBondContractsManager(request.collatralToken, address(lenderContracts[lender]), request.collatralAmount);
    require(status, 'transfer failed');
  }

  function lendToTokenToTokenBorrower(address lender, bondRequest memory request) public {
    require(msg.sender == bondManagerAddress, 'users must use the bond manager');
    int index = requestManager.indexOfBondRequest(request);
    require(index != -1, 'no bond request for this address');

    lenderContracts[lender] = new Lender(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );
    borrowerContracts[request.borrower] = new Borrower(
      request.borrower,
      lender,
      request.collatralToken,
      request.borrowingtoken,
      request.collatralAmount,
      request.borrowingAmount,
      request.durationInHours,
      request.intrestYearly
    );
    requestManager.deleteBondRequest(uint(index));

    bool status1 = transferFrom(request.borrowingtoken, lender, request.borrowingAmount);
    bool status2 = transfer(request.borrowingtoken, address(borrowerContracts[request.borrower]), request.borrowingAmount);
    bool status3 = requestManager.sendTokenFromBondContractsManager(request.collatralToken, address(lenderContracts[lender]), request.collatralAmount);
    require(status1 && status2 && status3, 'transferFrom failed');
  }
}
