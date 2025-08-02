# Solución para tamaño excesivo de contrato

El contrato `AdrianLabReplication` supera el límite de tamaño de 24576 bytes para despliegue en Ethereum Mainnet. Hemos implementado las siguientes soluciones para reducir el tamaño:

## 1. Biblioteca Externa

Hemos creado una biblioteca `AdrianLabLibrary.sol` para extraer funciones comunes y reducir el tamaño del contrato principal:

```solidity
// AdrianLabLibrary.sol
library AdrianLabLibrary {
    function uintToString(uint256 value) public pure returns (string memory) {...}
    function substring(string memory str, uint256 startIndex, uint256 endIndex) public pure returns (string memory) {...}
    function random(uint256 seed, uint256 max) public view returns (uint256) {...}
    // etc...
}
```

## 2. Refactorización de Código

Hemos dividido funciones grandes en funciones más pequeñas:

```solidity
// Antes: una función grande
function duplicateGen0Tokens(...) {...}

// Después: funciones pequeñas
function duplicateGen0Tokens(...) {
    _duplicateSingleToken(...);
}
function _duplicateSingleToken(...) {...}
function _recordDuplicationHistory(...) {...}
```

## 3. Optimización del Compilador

Para compilación, usa estos ajustes en Hardhat o Remix:

```javascript
// hardhat.config.js
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 50 // Valor bajo optimiza tamaño
      },
      viaIR: true,
      metadata: {
        bytecodeHash: "none",
      }
    }
  }
};
```

En Remix, habilita el optimizador con un valor bajo de "runs" (50-200).

## 4. Acortamiento de Mensajes de Error

Hemos acortado los mensajes de error para reducir el tamaño:

```solidity
// Antes
require(condition, "Este es un mensaje de error largo y detallado");

// Después
require(condition, "Error");
```

## 5. Instrucciones para Remix

1. Abre Remix IDE (https://remix.ethereum.org/)
2. Configura el compilador:
   - Activa "Enable optimization" y usa un valor bajo (50-200)
   - Selecciona versión 0.8.20 del compilador
3. Asegúrate de compilar en orden:
   - Primero `AdrianLabLibrary.sol`
   - Luego los contratos en el orden correcto de herencia

## 6. Solución alternativa: Proxy

Si las optimizaciones no son suficientes, considera usar un patrón proxy:

```solidity
// Contrato de implementación (grande)
contract AdrianLabImplementation {
    // Lógica completa aquí
}

// Contrato de proxy (pequeño)
contract AdrianLabProxy {
    address implementation;
    
    function execute(bytes memory data) external {
        (bool success, ) = implementation.delegatecall(data);
        require(success, "Failed");
    }
}
``` 