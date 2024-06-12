// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

struct allowanceEntry {
  address allower;
  address spender;
  address token;
  uint256 amount;
}

contract TokenBank {
  allowanceEntry[] allowanceEntries;

  function findAllowanceEntryWithMinimumBalance(address token, address allower, address spender, uint amount) public view returns (uint) {
    uint len = allowanceEntries.length;
    bool found = false;
    uint bestI = 0;
    uint closestAmount = amount;
    for(uint i = 0; i < len; i++) {
      if(allowanceEntries[i].spender == spender &&
         allowanceEntries[i].allower == allower &&
         allowanceEntries[i].token == token &&
         allowanceEntries[i].amount >= amount) {
        found = true;
        if(allowanceEntries[i].amount - amount < closestAmount) {
          bestI = i;
          closestAmount = allowanceEntries[i].amount - amount;
        }
      }
    }
    require(found, 'a allowance entry was not found with the minimum amount');
    return bestI;
  }

  function giveAddressAccessToToken(address token, address spender, uint amount) public returns (bool) {
    IERC20 tokenContract = IERC20(token);
    uint allowance = tokenContract.allowance(msg.sender, address(this));
    require(allowance >= amount, 'allowance is not high enough');
    allowanceEntries.push(allowanceEntry(msg.sender, spender, token, amount));
    console.log(token, msg.sender, spender, amount);
    bool status = tokenContract.transferFrom(msg.sender, address(this), amount);
    require(status, 'transferFrom failed');
    return status; 
  }

  function spendAllowedTokens(address token, address allower, address to, uint amount) public returns (bool) {
    console.log(token, allower, msg.sender, amount);
    uint index = findAllowanceEntryWithMinimumBalance(token, allower, msg.sender, amount);
    allowanceEntries[index].amount -= amount;
    if(allowanceEntries[index].amount == 0) delete allowanceEntries[index];
    IERC20 tokenContract = IERC20(token);
    return tokenContract.transfer(to, amount);
  }
}
