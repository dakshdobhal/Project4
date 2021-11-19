var HDWalletProvider = require("truffle-hdwallet-provider");
// var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";
var mnemonic = "robot boat soon reduce liquid food mobile sheriff core raw injury lift";

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*',
      gas: 6721975,
      gasPrice: 20000000000,
      confirmations: 0,
      timeoutBlocks: 50,
      skipDryRun: true,
    }  
  }
  ,
  compilers: {
    solc: {
      // version: "^0.4.24"
      version: "0.8.10"
    }
  }
};