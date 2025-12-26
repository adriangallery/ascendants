#!/usr/bin/env node
/**
 * Script de inicio robusto para Railway
 * Valida que estamos ejecutando el bot correcto antes de iniciar
 */

const fs = require('fs');
const path = require('path');

// Función helper para logging (compatible con Node.js)
function logDebug(location, message, data, hypothesisId) {
  const payload = JSON.stringify({
    location,
    message,
    data,
    timestamp: Date.now(),
    sessionId: 'debug-session',
    runId: 'run1',
    hypothesisId
  });
  
  // Usar fetch si está disponible (Node.js 18+), sino usar http
  if (typeof fetch !== 'undefined') {
    fetch('http://127.0.0.1:7242/ingest/7e4412d0-d04a-4fec-a842-10e1a74a267c', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: payload
    }).catch(() => {});
  } else {
    // Fallback para Node.js < 18
    const http = require('http');
    const options = {
      hostname: '127.0.0.1',
      port: 7242,
      path: '/ingest/7e4412d0-d04a-4fec-a842-10e1a74a267c',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    };
    const req = http.request(options, () => {});
    req.on('error', () => {});
    req.write(payload);
    req.end();
  }
}

// #region agent log
logDebug('start.js:10', 'start.js ejecutándose', { argv: process.argv, cwd: process.cwd(), __dirname: __dirname }, 'A');
// #endregion

console.log('========================================');
console.log('🔍 VALIDACIÓN PRE-INICIO');
console.log('========================================');

// Obtener directorio actual
const currentDir = process.cwd();
console.log(`📁 Directorio actual: ${currentDir}`);
console.log(`📁 __dirname: ${__dirname}`);
console.log(`📁 process.argv: ${JSON.stringify(process.argv)}`);

// #region agent log
logDebug('start.js:35', 'Directorio actual detectado', { currentDir, __dirname, argv: process.argv }, 'B');
// #endregion

// Intentar encontrar package.json
let packagePath = path.join(currentDir, 'package.json');
// #region agent log
logDebug('start.js:42', 'Buscando package.json', { packagePath, exists: fs.existsSync(packagePath) }, 'C');
// #endregion

if (!fs.existsSync(packagePath)) {
  // Intentar desde adrian-arbitrage-bot
  const adrianDir = path.join(currentDir, 'adrian-arbitrage-bot');
  // #region agent log
  logDebug('start.js:47', 'Package.json no encontrado en raíz, buscando en adrian-arbitrage-bot', { adrianDir, exists: fs.existsSync(adrianDir) }, 'D');
  // #endregion
  if (fs.existsSync(adrianDir)) {
    packagePath = path.join(adrianDir, 'package.json');
    console.log(`📁 Intentando desde: ${adrianDir}`);
  }
}

if (!fs.existsSync(packagePath)) {
  console.error('❌ ERROR: No se encontró package.json');
  console.error(`   Buscado en: ${packagePath}`);
  process.exit(1);
}

console.log(`📦 Package.json encontrado: ${packagePath}`);

// Leer package.json
let packageJson;
try {
  packageJson = require(packagePath);
} catch (error) {
  console.error('❌ ERROR: No se pudo leer package.json');
  console.error(`   Error: ${error.message}`);
  process.exit(1);
}

const packageName = packageJson?.name;
console.log(`📛 Package name: ${packageName}`);

// #region agent log
logDebug('start.js:70', 'Package name detectado', { packageName, packagePath, expected: 'adrian-arbitrage-bot', isCorrect: packageName === 'adrian-arbitrage-bot' }, 'E');
// #endregion

// VALIDACIÓN CRÍTICA: Debe ser adrian-arbitrage-bot
if (packageName !== 'adrian-arbitrage-bot') {
  // #region agent log
  logDebug('start.js:74', 'ERROR: Bot incorrecto detectado', { packageName, packagePath, currentDir, expected: 'adrian-arbitrage-bot' }, 'F');
  // #endregion
  console.error('\n========================================');
  console.error('❌ ERROR CRÍTICO: Bot incorrecto detectado');
  console.error('========================================');
  console.error(`Esperado: adrian-arbitrage-bot`);
  console.error(`Detectado: ${packageName}`);
  console.error(`Package path: ${packagePath}`);
  console.error(`Directorio actual: ${currentDir}`);
  console.error('========================================');
  console.error('\nRailway está ejecutando el código incorrecto.');
  console.error('\nSOLUCIÓN:');
  console.error('1. Settings → Source → Root Directory: VACÍO');
  console.error('2. Settings → Build → Build Command:');
  console.error('   cd adrian-arbitrage-bot && npm install && npm run build');
  console.error('3. Settings → Deploy → Start Command:');
  console.error('   cd adrian-arbitrage-bot && node start.js');
  console.error('4. Settings → Build → Watch Paths: adrian-arbitrage-bot/**');
  console.error('========================================\n');
  process.exit(1);
}

// Verificar que dist/bot.js existe
const distPath = path.join(path.dirname(packagePath), 'dist', 'bot.js');
// #region agent log
logDebug('start.js:99', 'Verificando dist/bot.js', { distPath, exists: fs.existsSync(distPath), packageDir: path.dirname(packagePath) }, 'G');
// #endregion

if (!fs.existsSync(distPath)) {
  // #region agent log
  logDebug('start.js:103', 'ERROR: dist/bot.js no encontrado', { distPath, packageDir: path.dirname(packagePath) }, 'H');
  // #endregion
  console.error('❌ ERROR: No se encontró dist/bot.js');
  console.error(`   Buscado en: ${distPath}`);
  console.error('   Asegúrate de que el build se completó correctamente.');
  process.exit(1);
}

console.log(`✅ Validación pasada`);
console.log(`🚀 Ejecutando: ${distPath}`);
console.log('========================================\n');

// #region agent log
logDebug('start.js:117', 'Validación pasada, ejecutando bot', { distPath, packageName }, 'I');
// #endregion

// Ejecutar el bot
require(distPath);

