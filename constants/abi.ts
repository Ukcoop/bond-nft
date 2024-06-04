export default {
  token: [
    'function approve(address spender, uint256 value) public returns (bool)'
  ],
  borrower: [
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "borrower1",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "lender1",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "collatralToken1",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "borrowingToken1",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "borrowingAmount1",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "collatralAmount1",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "durationInHours1",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "intrestYearly1",
          "type": "uint256"
        }
      ],
      "stateMutability": "nonpayable",
      "type": "constructor"
    },
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": false,
          "internalType": "address",
          "name": "sender",
          "type": "address"
        },
        {
          "indexed": false,
          "internalType": "address",
          "name": "borrower",
          "type": "address"
        },
        {
          "indexed": false,
          "internalType": "uint256",
          "name": "amount",
          "type": "uint256"
        }
      ],
      "name": "Deposit",
      "type": "event"
    },
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": false,
          "internalType": "address",
          "name": "borrower",
          "type": "address"
        },
        {
          "indexed": false,
          "internalType": "uint256",
          "name": "amount",
          "type": "uint256"
        }
      ],
      "name": "Withdraw",
      "type": "event"
    },
    {
      "inputs": [],
      "name": "depositBorrowedETH",
      "outputs": [],
      "stateMutability": "payable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "amount",
          "type": "uint256"
        }
      ],
      "name": "depositBorrowedTokens",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "getData",
      "outputs": [
        {
          "components": [
            {
              "internalType": "address",
              "name": "borrower",
              "type": "address"
            },
            {
              "internalType": "address",
              "name": "lender",
              "type": "address"
            },
            {
              "internalType": "address",
              "name": "collatralToken",
              "type": "address"
            },
            {
              "internalType": "address",
              "name": "borrowingToken",
              "type": "address"
            },
            {
              "internalType": "uint256",
              "name": "collatralAmount",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "borrowingAmount",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "durationInHours",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "intrestYearly",
              "type": "uint256"
            }
          ],
          "internalType": "struct getDataResponse",
          "name": "",
          "type": "tuple"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "liquidate",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "amount",
          "type": "uint256"
        }
      ],
      "name": "withdrawBorrowedETH",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "amount",
          "type": "uint256"
        }
      ],
      "name": "withdrawBorrowedTokens",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "stateMutability": "payable",
      "type": "receive"
    }
  ],
  lender: [
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "borrower1",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "lender1",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "collatralToken1",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "borrowingToken1",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "borrowingAmount1",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "durationInHours1",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "intrestYearly1",
          "type": "uint256"
        }
      ],
      "stateMutability": "nonpayable",
      "type": "constructor"
    },
    {
      "inputs": [],
      "name": "ReentrancyGuardReentrantCall",
      "type": "error"
    },
    {
      "inputs": [],
      "name": "setLiquidation",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "withdawLentTokens",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "stateMutability": "payable",
      "type": "receive"
    }
  ]
}
