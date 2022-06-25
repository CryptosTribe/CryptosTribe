require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-solhint");


module.exports = {
    defaultNetwork: "testnet", networks: {
        hardhat: {
            allowUnlimitedContractSize: false,
        },
        mainnet: {
            url: "https://bsc-dataseed1.binance.org/",
        }, testnet: {
            url: "https://data-seed-prebsc-1-s1.binance.org:8545",
        }
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY
    },
    solidity: {
        compilers: [
            {
                version: "0.8.7",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 800
                    }
                },
            }
        ]
    }
};
