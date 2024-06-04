// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import './borrowerNFT.sol';
import './lenderNFT.sol';
import './bondManagerUtils/requestManager.sol';
import './bondManagerUtils/bondContractsManager.sol';

contract BondManager {
  mapping(address => Borrower) public borrowerContracts;
  mapping(address => Lender) public lenderContracts;
  RequestManager immutable requestManager;
  BondContractsManager immutable bondContractsManager;

  constructor(address _requestManagerAddress, address _bondContractsManagerAddress) {
    requestManager = RequestManager(_requestManagerAddress);
    bondContractsManager = BondContractsManager(_bondContractsManagerAddress);
  }

  // slither-disable-start low-level-calls
  // slither-disable-start arbitrary-send-eth
  function sendViaCall(address payable to, uint value) public payable {
    require(to != payable(address(0)), 'cant send to the 0 address');
    require(value != 0, 'can not send nothing');
    (bool sent,) = to.call{value: value}('');
    require(sent, 'Failed to send Ether');
  }
  // slither-disable-end low-level-calls
  // slither-disable-end arbitrary-send-eth

  function getRequestManagerAddress() public view returns (address) {
    return address(requestManager);
  }

  function getBondContractsManagerAddress() public view returns (address) {
    return address(bondContractsManager);
  }

  function postETHToTokenbondRequest(
    address borrowingToken,
    uint borrowingAmount,
    uint termInHours,
    uint intrestYearly
  ) public payable returns (bool) {
    return requestManager.postETHToTokenbondRequest{value: msg.value}(msg.sender, borrowingToken, borrowingAmount, termInHours, intrestYearly);
  }

  function postTokenToETHBondRequest(
    address collatralToken,
    uint collatralAmount,
    uint borrowingAmount,
    uint termInHours,
    uint intrestYearly
  ) public returns (bool) {
    return requestManager.postTokenToETHBondRequest(msg.sender, collatralToken, collatralAmount, borrowingAmount, termInHours, intrestYearly);
  }

  function postTokenToTokenbondRequest(
    address collatralToken,
    uint collatralAmount,
    address borrowingToken,
    uint borrowingAmount,
    uint termInHours,
    uint intrestYearly
  ) public returns (bool) {
    return requestManager.postTokenToTokenbondRequest(msg.sender, collatralToken, collatralAmount, borrowingToken, borrowingAmount, termInHours, intrestYearly);
  }

  function getAddressOfBorrowerContract(address borrower) public view returns (address) {
    return bondContractsManager.getAddressOfBorrowerContract(borrower);
  }

  function getAddressOfLenderContract(address lender) public view returns (address) {
    return bondContractsManager.getAddressOfLenderContract(lender);
  }

  function liquifyFromBorrower(address borrower, address lender) public {
    bondContractsManager.liquifyFromBorrower(borrower, lender);
  }

  function cancelETHToTokenBondRequest(bondRequest memory request) public returns (bool) {
    return requestManager.cancelETHToTokenBondRequest(msg.sender, request);
  }

  function cancelTokenToTokenBondRequest(bondRequest memory request) public payable returns (bool) {
    return requestManager.cancelTokenToTokenBondRequest(msg.sender, request);
  }

  function getBondRequests() public view returns (bondRequest[] memory) {
    return requestManager.getBondRequests();
  }

  function lendToETHToTokenBorrower(bondRequest memory request) public payable {
    bondContractsManager.lendToETHToTokenBorrower(msg.sender, request); 
  }

  function lendToTokenToETHBorrower(bondRequest memory request) public payable {
    bondContractsManager.lendToTokenToETHBorrower{value: msg.value}(msg.sender, request);
  }

  function lendToTokenToTokenBorrower(bondRequest memory request) public {
    bondContractsManager.lendToTokenToTokenBorrower(msg.sender, request);
  }
}
