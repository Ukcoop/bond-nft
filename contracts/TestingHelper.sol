// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface Irouter {
  //slither-disable-next-line naming-convention
  function WETH() external pure returns (address);
  function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
  function getAmountsIn(uint amountOut, address[] memory path) external view returns (uint[] memory amounts);
  function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts);
  function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
  function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
}

contract TestingHelper {
  Irouter immutable router;

  constructor() {
    router = Irouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
  }

  function swapETHforToken(address token) public payable returns (uint) {
    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = token;

    uint[] memory amountsOut = router.getAmountsOut(msg.value, path);
    uint outMin = amountsOut[1] - (amountsOut[1] / 10);

    return router.swapExactETHForTokens{value: msg.value}(outMin, path, msg.sender, block.timestamp + 1200)[1];
  }
  
  function swapTokenForETH(address token, uint amount) public returns (uint) {
    address[] memory path = new address[](2);
    path[0] = token;
    path[1] = router.WETH();

    uint[] memory amountsOut = router.getAmountsOut(amount, path);
    uint outMin = amountsOut[1] - (amountsOut[1] / 10);

    IERC20 tokenContract = IERC20(token);
    require(tokenContract.allowance(msg.sender, address(this)) >= amount, 'allowance is not high enough');
    bool status = tokenContract.transferFrom(msg.sender, address(this), amount);
    require(status, 'transferFrom, failed');
    status = tokenContract.approve(address(router), amount);
    require(status, 'approve failed');

    return router.swapExactTokensForETH(amount, outMin, path, msg.sender, block.timestamp + 1200)[1]; 
  }

  function swapTokenForToken(address tokenA, address tokenB, uint amount) public returns (uint) {
    address[] memory path = new address[](2);
    path[0] = tokenA;
    path[1] = tokenB;

    IERC20 tokenContract = IERC20(tokenA);
    require(tokenContract.allowance(msg.sender, address(this)) >= amount, 'allowance is not high enough');
    bool status = tokenContract.transferFrom(msg.sender, address(this), amount);
    require(status, 'transferFrom, failed');
    status = tokenContract.approve(address(router), amount);
    require(status, 'approve failed');

    uint resAmount = router.getAmountsOut(amount, path)[1];
    return router.swapExactTokensForTokens(amount, resAmount, path, msg.sender, block.timestamp + 1200)[1];
  }

  function getTokenBalance(address token) public view returns (uint) {
    return IERC20(token).balanceOf(msg.sender);
  }

  function getAmountIn(address input, address output, uint amountRequired) public view returns (uint) {
    address[] memory path = new address[](2);
    path[0] = input;
    path[1] = output;
    return router.getAmountsIn(amountRequired, path)[0];
  }
}
