require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-waffle");
require("hardhat-contract-sizer");


module.exports = {
  solidity: "0.8.6",
  settings: {
    optimizer: {
      enabled: true,
      runs: 1000,
    },
  },
};
