## Methods
| **Symbol** | **Meaning**                                                                              |
| :--------: | :--------------------------------------------------------------------------------------- |
|    **◯**   | Execution gas for this method does not include intrinsic gas overhead                    |
|    **△**   | Cost was non-zero but below the precision setting for the currency display (see options) |

|                                   |     Min |     Max |     Avg | Calls | usd avg |
| :-------------------------------- | ------: | ------: | ------: | ----: | ------: |
| **BondContractsManager**          |         |         |         |       |         |
|        *lendToBorrower*           | 501,870 | 542,414 | 527,367 |     6 |       - |
|        *setAddress*               |       - |       - |  44,186 |     1 |       - |
|        *withdraw*                 | 103,884 | 132,887 | 116,296 |     3 |       - |
| **BondManager**                   |         |         |         |       |         |
|        *performUpkeep*            | 233,815 | 380,427 | 324,314 |     6 |       - |
| **Borrower**                      |         |         |         |       |         |
|        *deposit*                  |  65,469 | 101,317 |  83,393 |     4 |       - |
|        *withdraw*                 |  96,624 | 127,899 | 112,262 |     4 |       - |
| **BorrowerNFTManager**            |         |         |         |       |         |
|        *approve*                  |  56,298 |  60,059 |  56,925 |    12 |       - |
| **RequestManager**                |         |         |         |       |         |
|        *cancelBondRequest*        |  47,477 | 108,370 |  77,924 |     4 |       - |
|        *postBondRequest*          | 138,326 | 179,404 | 164,074 |    10 |       - |
|        *setAddress*               |       - |       - |  66,764 |     1 |       - |
| **TestingHelper**                 |         |         |         |       |         |
|        *swapETHforToken*          | 144,948 | 165,312 | 155,861 |    10 |       - |
| **TokenBank**                     |         |         |         |       |         |
|        *giveAddressAccessToToken* | 142,534 | 181,534 | 161,290 |    10 |       - |

## Deployments
|                          | Min | Max  |       Avg | Block % | usd avg |
| :----------------------- | --: | ---: | --------: | ------: | ------: |
| **BondContractsManager** |   - |    - | 9,380,060 |  31.3 % |       - |
| **BondManager**          |   - |    - |   593,206 |     2 % |       - |
| **PriceOracleManager**   |   - |    - |   817,134 |   2.7 % |       - |
| **RequestManager**       |   - |    - | 1,739,931 |   5.8 % |       - |
| **TestingHelper**        |   - |    - | 1,043,600 |   3.5 % |       - |
| **TokenBank**            |   - |    - |   656,408 |   2.2 % |       - |

## Solidity and Network Config
| **Settings**        | **Value**  |
| ------------------- | ---------- |
| Solidity: version   | 0.8.20     |
| Solidity: optimized | true       |
| Solidity: runs      | 200        |
| Solidity: viaIR     | false      |
| Block Limit         | 30,000,000 |
| Gas Price           | -          |
| Token Price         | -          |
| Network             | ETHEREUM   |
| Toolchain           | hardhat    |

