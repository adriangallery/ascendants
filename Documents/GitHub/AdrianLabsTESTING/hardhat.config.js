// require("@nomicfoundation/hardhat-toolbox");
require("hardhat-contract-sizer");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 50  // Un valor más bajo optimiza para tamaño en lugar de gas
      },
      // Reduce el tamaño del bytecode
      viaIR: true,
      // Eliminar data innecesaria del bytecode
      metadata: {
        bytecodeHash: "none",
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 1337,
      allowUnlimitedContractSize: true, // Para pruebas permitimos contratos grandes
      gas: 12000000,
      blockGasLimit: 12000000,
    },
    // Configuración para el deploy final con límite de tamaño habilitado
    hardhat_prod: {
      chainId: 1337,
      allowUnlimitedContractSize: false, // Para verificar tamaño de contratos
      gas: 12000000,
      blockGasLimit: 12000000,
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  }
}; 