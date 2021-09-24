const HDWalletProvider = require('@truffle/hdwallet-provider');
//const PrivateKeyProvider = require("truffle-privatekey-provider");
const fs = require('fs');
const mnemonic = fs.readFileSync(".secret").toString().trim();

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
    },
    matic: {
      //provider: () => new HDWalletProvider(mnemonic, `wss://rpc-mainnet.maticvigil.com/ws/v1/2c99a0a314bc4c854a7ccd7b69d65e2713e1ef90`),https://polygon-rpc.com
      provider: () => new HDWalletProvider(mnemonic, `https://polygon-mainnet.infura.io/v3/e95c3e3d2d81441a8552117699ffa5bd`),
      network_id: 137,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      gasPrice: 10000000000,
      networkCheckTimeout:1000000,
      gasLimit: 20000000,
      gas: 20000000
    },
    aurora: {
      provider: () => new HDWalletProvider(mnemonic, `https://mainnet.aurora.dev`),
      network_id: 1313161554,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      gasPrice: 10000000000,
      networkCheckTimeout:1000000
    }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: '0.6.12',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
}
