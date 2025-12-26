#!/usr/bin/env node
/**
 * Script wrapper para ejecutar el Adrian Arbitrage Bot desde la raíz del repo
 * Este script se asegura de que se ejecute el bot correcto incluso si Railway
 * está configurado incorrectamente.
 * 
 * CRÍTICO: Este script DEBE ejecutarse desde la raíz del repositorio.
 * Si Railway está ejecutando este script desde otro directorio, fallará inmediatamente.
 */

const fs = require('fs');
const path = require('path');

console.log('========================================');
console.log('🚀 ADRIAN ARBITRAGE BOT - WRAPPER');
console.log('========================================');

const currentDir = process.cwd();
console.log(`📁 Directorio actual (wrapper): ${currentDir}`);
console.log(`📁 __dirname: ${__dirname}`);
console.log(`📁 process.argv: ${JSON.stringify(process.argv)}`);

// VALIDACIÓN CRÍTICA 1: Verificar que estamos en la raíz del repo
// Buscar el directorio adrian-arbitrage-bot desde el directorio actual
const adrianBotDir = path.join(currentDir, 'adrian-arbitrage-bot');
const packageJsonPath = path.join(adrianBotDir, 'package.json');

console.log(`🔍 Buscando package.json en: ${packageJsonPath}`);

if (!fs.existsSync(packageJsonPath)) {
  console.error('\n========================================');
  console.error('❌ ERROR CRÍTICO: No se encontró adrian-arbitrage-bot/package.json');
  console.error('========================================');
  console.error(`   Buscado en: ${packageJsonPath}`);
  console.error(`   Directorio actual: ${currentDir}`);
  console.error('========================================');
  console.error('\nRailway está ejecutando este script desde el directorio incorrecto.');
  console.error('\nSOLUCIÓN:');
  console.error('1. Settings → Source → Root Directory: VACÍO (completamente vacío)');
  console.error('2. Settings → Deploy → Start Command: node start-adrian-bot.js');
  console.error('3. Asegúrate de que NO hay comandos como "npm run start:prod" en Start Command');
  console.error('========================================\n');
  process.exit(1);
}

// VALIDACIÓN CRÍTICA 2: Verificar que es el package.json correcto
let packageJson;
try {
  packageJson = require(packageJsonPath);
} catch (error) {
  console.error('❌ ERROR: No se pudo leer package.json');
  console.error(`   Error: ${error.message}`);
  process.exit(1);
}

if (packageJson.name !== 'adrian-arbitrage-bot') {
  console.error('\n========================================');
  console.error('❌ ERROR CRÍTICO: Package.json incorrecto detectado');
  console.error('========================================');
  console.error(`   Esperado: adrian-arbitrage-bot`);
  console.error(`   Detectado: ${packageJson.name}`);
  console.error(`   Ruta: ${packageJsonPath}`);
  console.error('========================================');
  console.error('\nRailway está ejecutando el código del bot incorrecto.');
  console.error('Esto significa que Railway está en el directorio del NFT bot.');
  console.error('\nSOLUCIÓN:');
  console.error('1. Settings → Source → Root Directory: VACÍO (completamente vacío)');
  console.error('2. Settings → Deploy → Start Command: node start-adrian-bot.js');
  console.error('3. NO uses "npm run start:prod" - ese comando ejecuta el bot incorrecto');
  console.error('========================================\n');
  process.exit(1);
}

console.log(`✅ Bot correcto detectado: ${packageJson.name}`);
console.log(`📦 Directorio del bot: ${adrianBotDir}`);

// VALIDACIÓN CRÍTICA 3: Verificar que start.js existe
const startScriptPath = path.join(adrianBotDir, 'start.js');
if (!fs.existsSync(startScriptPath)) {
  console.error('❌ ERROR: No se encontró start.js en el directorio del bot');
  console.error(`   Buscado en: ${startScriptPath}`);
  console.error('   Asegúrate de que el build se completó correctamente.');
  process.exit(1);
}

console.log(`✅ start.js encontrado: ${startScriptPath}`);
console.log(`🚀 Cambiando al directorio del bot y ejecutando start.js...`);
console.log('========================================\n');

// Cambiar al directorio del bot y ejecutar start.js
try {
  process.chdir(adrianBotDir);
  console.log(`📁 Directorio cambiado a: ${process.cwd()}`);
  require(startScriptPath);
} catch (error) {
  console.error('❌ ERROR al ejecutar el bot:');
  console.error(error.message);
  console.error(error.stack);
  process.exit(1);
}

