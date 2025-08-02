const fs = require('fs');
const path = require('path');

const contractsDir = path.join(__dirname, '../contracts');

// Lista de contratos principales a verificar
const mainContracts = [
  'AdrianLabReplication.sol',
  'AdrianLabQuery.sol',
  'AdrianLabAdmin.sol',
  'AdrianLabHistory.sol',
  'AdrianLabBase.sol',
  'AdrianLabTrait.sol',
  'AdrianLabLibrary.sol'
];

console.log('Analizando tamaño de contratos:');
console.log('-----------------------------');

mainContracts.forEach(contractName => {
  const contractPath = path.join(contractsDir, contractName);
  
  if (fs.existsSync(contractPath)) {
    const stats = fs.statSync(contractPath);
    const fileSizeInKB = stats.size / 1024;
    const content = fs.readFileSync(contractPath, 'utf8');
    const lines = content.split('\n').length;
    
    console.log(`${contractName}:`);
    console.log(`  Tamaño: ${fileSizeInKB.toFixed(2)} KB`);
    console.log(`  Líneas: ${lines}`);
    
    // Una estimación muy aproximada del bytecode basada en el tamaño del archivo
    // Esto no es preciso, pero puede dar una idea
    const estimatedBytecodeSize = Math.round(stats.size * 0.8);
    console.log(`  Tamaño bytecode estimado: ${estimatedBytecodeSize} bytes`);
    console.log(`  Porcentaje del límite (24576 bytes): ${((estimatedBytecodeSize / 24576) * 100).toFixed(2)}%`);
    console.log('-----------------------------');
  } else {
    console.log(`${contractName}: No encontrado`);
    console.log('-----------------------------');
  }
});

console.log('\nNota: El tamaño estimado del bytecode es solo una aproximación y no representa el tamaño real después de la compilación.');
console.log('Para obtener valores precisos, es necesario compilar los contratos con el optimizador habilitado.'); 