require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-waffle");
require("hardhat-contract-sizer");
require("solidity-coverage");
require("hardhat-deploy");
require("hardhat-deploy-ethers");

module.exports = {
  solidity: "0.8.6",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${
        process.env.ALCHEMY_PROJECT_ID || ""
      }`,
      accounts: process.env.RINKEBY_PRIVATE_KEY
        ? [process.env.RINKEBY_PRIVATE_KEY]
        : [],
      gas: 2100000,
      gasPrice: 8000000000,
      saveDeployments: true,
    },
  },
  settings: {
    optimizer: {
      enabled: true,
      runs: 1000,
    },
  },
  contractSizer: {
    strict: true,
  },
  namedAccounts: {
    deployer: 0,
    dev: 1,
  },
};
