require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config()


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: process.env.RPC_URL,
      }
    }
  },
  solidity: {
    compilers: [
      {version: "0.6.12"},
      {version: "0.8.0"},
      {version: "0.8.1"},
      {version: "0.8.2"}
    ],
  },
  mocha: {
    timeout: 100000000
  }
};
