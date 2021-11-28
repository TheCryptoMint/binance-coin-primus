require('dotenv').config();
require('@babel/register');
require('babel-polyfill');

const HDWalletProvider = require("@truffle/hdwallet-provider");

const { env } = process;

const getBSCWalletProvider = networkName => {
  const endpoint = (
    networkName === 'testnet' ?
    `https://data-seed-prebsc-1-s1.binance.org:8545` :
    `https://bsc-dataseed1.binance.org`
  );
  return new HDWalletProvider(env.MNEMONIC, endpoint);
};

module.exports = {
  api_keys: {
    bscscan: env.BSCSCAN_API_KEY,
  },
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*", // Any network (default: none)
      from: `${ env.MINTER_ADDRESS_LOCALHOST }`,
      gasPrice: '0x64',
    },
    bscTestnet: {
      provider: () => getBSCWalletProvider('testnet'),
      from: `${ env.MINTER_ADDRESS }`,
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    bsc: {
      provider: () => getBSCWalletProvider('mainnet'),
      from: `${ env.MINTER_ADDRESS }`,
      network_id: 56,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    },
  },
  contracts_directory: './contracts/',
  contracts_build_directory: './abis/',
  compilers: {
    solc: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      version: "^0.8.0"
    },
  },
  plugins: [
    "truffle-contract-size",
    "truffle-plugin-verify",
  ]
};
