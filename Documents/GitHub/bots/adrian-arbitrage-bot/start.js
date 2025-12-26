#!/usr/bin/env node
/**
 * Script de inicio robusto para Railway
 * Valida que estamos ejecutando el bot correcto antes de iniciar
 */

const fs = require('fs');
const path = require('path');

console.log('========================================');
console.log('🔍 VALIDACIÓN PRE-INICIO');
console.log('========================================');

// Obtener directorio actual
const currentDir = process.cwd();
console.log(`📁 Directorio actual: ${currentDir}`);

// Intentar encontrar package.json
let packagePath = path.join(currentDir, 'package.json');
if (!fs.existsSync(packagePath)) {
  // Intentar desde adrian-arbitrage-bot
  const adrianDir = path.join(currentDir, 'adrian-arbitrage-bot');
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

// VALIDACIÓN CRÍTICA: Debe ser adrian-arbitrage-bot
if (packageName !== 'adrian-arbitrage-bot') {
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
if (!fs.existsSync(distPath)) {
  console.error('❌ ERROR: No se encontró dist/bot.js');
  console.error(`   Buscado en: ${distPath}`);
  console.error('   Asegúrate de que el build se completó correctamente.');
  process.exit(1);
}

console.log(`✅ Validación pasada`);
console.log(`🚀 Ejecutando: ${distPath}`);
console.log('========================================\n');

// Ejecutar el bot
require(distPath);

