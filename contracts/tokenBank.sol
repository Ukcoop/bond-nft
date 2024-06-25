// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct allowanceEntry {
  address allower;
  address spender;
  address token;
  uint256 amount;
}

struct bondBankAccount {
  uint32 borrowerId;
  uint32 lenderId;
  address collatralToken;
  address borrowingToken;
  uint256 borrowingAmount;
}

contract TokenBank {
  allowanceEntry[] internal allowanceEntries;

  function findAllowanceEntryWithMinimumBalance(address token, address allower, address spender, uint amount) public view returns (uint bestI) {
    require(token != address(0), 'token address can not be address(0)');
    require(allower != address(0), 'allower address can not be address(0)');
    require(spender != address(0), 'spender address can not beaddress(0)');
    require(amount != 0, 'amount can not be 0');
    uint len = allowanceEntries.length;
    bool found = false;
    uint closestAmount = amount;
    for(uint i; i < len; i++) {
      if(allowanceEntries[i].spender == spender &&
         allowanceEntries[i].allower == allower &&
         allowanceEntries[i].token == token &&
         allowanceEntries[i].amount >= amount) {
        if(allowanceEntries[i].amount >= amount && !found || (allowanceEntries[i].amount - amount < closestAmount)) {
          found = true;
          bestI = i;
          closestAmount = allowanceEntries[i].amount - amount;
        }
      }
    }
    require(found, 'a allowance entry was not found with the minimum amount');
  }

  function giveAddressAccessToToken(address token, address spender, uint amount) public returns (bool status) {
    require(token != address(0), 'token address can not be address(0)');
    require(spender != address(0), 'spender address can not beaddress(0)');
    require(amount != 0, 'amount can not be 0');
    IERC20 tokenContract = IERC20(token);
    uint allowance = tokenContract.allowance(msg.sender, address(this));
    require(allowance >= amount, 'allowance is not high enough');
    allowanceEntries.push(allowanceEntry(msg.sender, spender, token, amount));
    status = tokenContract.transferFrom(msg.sender, address(this), amount);
    require(status, 'transferFrom failed');
  }

  function spendAllowedTokens(address token, address allower, address to, uint amount) public returns (bool) {
    require(token != address(0), 'token address can not be address(0)');
    require(allower != address(0), 'allower address can not be address(0)');
    require(to != address(0), 'to address can not be address(0)');
    require(amount != 0, 'amount can not be 0');
    uint index = findAllowanceEntryWithMinimumBalance(token, allower, msg.sender, amount);
    allowanceEntries[index].amount -= amount;
    if(allowanceEntries[index].amount == 0) delete allowanceEntries[index];
    IERC20 tokenContract = IERC20(token);
    return tokenContract.transfer(to, amount);
  }
}
