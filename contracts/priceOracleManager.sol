// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface Ioracle {
  function latestAnswer() external view returns (int256 answer);
  function decimals() external view returns (uint8);
}

struct oraclePair {
  address addressA;
  address addressB;
}

contract PriceOracleManager {
  mapping(bytes32 => address) oracles;

  function getOracleKey(address addressA, address addressB) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(addressA, addressB));
  }
  
  constructor() {
    oracles[getOracleKey(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)] = 0xc5a90A6d7e4Af242dA238FFe279e9f2BA0c64B2e;// WBTC/ETH => BTC/ETH
    oracles[getOracleKey(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9)] = 0x6ce185860a4963106506C203335A2910413708e9;// WBTC/USDT => BTC/USD
    oracles[getOracleKey(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8)] = 0x6ce185860a4963106506C203335A2910413708e9;// WBTC/bridged USDC => BTC/USD
    oracles[getOracleKey(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, 0xaf88d065e77c8cC2239327C5EDb3A432268e5831)] = 0x6ce185860a4963106506C203335A2910413708e9;// WBTC/USDC => BTC/USD
    oracles[getOracleKey(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1)] = 0x6ce185860a4963106506C203335A2910413708e9;// WBTC/DAI => BTC/USD
    oracles[getOracleKey(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, 0x680447595e8b7b3Aa1B43beB9f6098C79ac2Ab3f)] = 0x6ce185860a4963106506C203335A2910413708e9;// WBTC/USDD => BTC/USD
    oracles[getOracleKey(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, 0x4D15a3A2286D883AF0AA1B3f21367843FAc63E07)] = 0x6ce185860a4963106506C203335A2910413708e9;// WBTC/TUSD => BTC/USD
    oracles[getOracleKey(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9)] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;// ETH/USDT => ETH/USD
    oracles[getOracleKey(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8)] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;// ETH/bridged USDC => ETH/USD
    oracles[getOracleKey(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, 0xaf88d065e77c8cC2239327C5EDb3A432268e5831)] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;// ETH/USDC => ETH/USD
    oracles[getOracleKey(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1)] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;// ETH/DAI => ETH/USD
    oracles[getOracleKey(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, 0x680447595e8b7b3Aa1B43beB9f6098C79ac2Ab3f)] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;// ETH/USDD => ETH/USD
    oracles[getOracleKey(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, 0x4D15a3A2286D883AF0AA1B3f21367843FAc63E07)] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;// ETH/TUSD => ETH/USD
  }

  function isConstant(address addressA, address addressB) internal view returns (bool) {
    return (oracles[getOracleKey(addressA, addressB)] == address(0) && oracles[getOracleKey(addressB, addressA)] == address(0));
  }

  function needsInversed(address addressA, address addressB) internal view returns (bool) {
    return (oracles[getOracleKey(addressB, addressA)] != address(0));
  }
  
  //slither-disable-next-line naming-convention  
  function toERC20Decimals(uint amount, uint oracleDecimals, uint ERC20Decimals) internal pure returns (uint) {
    if(ERC20Decimals > oracleDecimals) return amount * (10 ** (ERC20Decimals - oracleDecimals));
    if(oracleDecimals > ERC20Decimals) return amount / (10 ** (oracleDecimals - ERC20Decimals));
    return amount;
  }

  // slither-disable-start divide-before-multiply
  function getInversedPrice(uint amount, address addressA, address addressB) internal view returns (uint inverted) {
    Ioracle oracle = Ioracle(oracles[getOracleKey(addressB, addressA)]); // the price we want to invert
    uint decimalsA = IERC20Metadata(addressA).decimals(); 
    uint decimalsB = IERC20Metadata(addressB).decimals();

    // Retrieve the BTC/ETH price from the oracle
    uint price = uint(oracle.latestAnswer());
    uint oracleDecimals = 10 ** oracle.decimals();
    
    uint inverse = ((10 ** decimalsB) * oracleDecimals) / price;
    inverted = (inverse * amount) / (10 ** decimalsA);
  }
  // slither-disable-end divide-before-multiply



  function getPrice(uint amount, address addressA, address addressB) public view returns (uint) {
    if(isConstant(addressA, addressB)) {
      return (10 ** IERC20Metadata(addressB).decimals()); 
    }

    uint price = 0;

    if(needsInversed(addressA, addressB)) {
      price = getInversedPrice(amount, addressA, addressB);
    } else {
      Ioracle oracle = Ioracle(oracles[getOracleKey(addressA, addressB)]);
      price = toERC20Decimals(uint(oracle.latestAnswer()), oracle.decimals(), IERC20Metadata(addressB).decimals());
    }

    return price;
  }
}
