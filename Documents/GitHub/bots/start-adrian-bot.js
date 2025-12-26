#!/usr/bin/env node
/**
 * Script wrapper para ejecutar el Adrian Arbitrage Bot desde la raíz del repo
 * Este script se asegura de que se ejecute el bot correcto incluso si Railway
 * está configurado incorrectamente.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('========================================');
console.log('🚀 ADRIAN ARBITRAGE BOT - WRAPPER');
console.log('========================================');

const currentDir = process.cwd();
console.log(`📁 Directorio actual: ${currentDir}`);

// Buscar el directorio adrian-arbitrage-bot
const adrianBotDir = path.join(currentDir, 'adrian-arbitrage-bot');
const packageJsonPath = path.join(adrianBotDir, 'package.json');

if (!fs.existsSync(packageJsonPath)) {
  console.error('❌ ERROR: No se encontró adrian-arbitrage-bot/package.json');
  console.error(`   Buscado en: ${packageJsonPath}`);
  process.exit(1);
}

// Verificar que es el package.json correcto
const packageJson = require(packageJsonPath);
if (packageJson.name !== 'adrian-arbitrage-bot') {
  console.error('❌ ERROR: Package.json incorrecto detectado');
  console.error(`   Esperado: adrian-arbitrage-bot`);
  console.error(`   Detectado: ${packageJson.name}`);
  process.exit(1);
}

console.log(`✅ Bot correcto detectado: ${packageJson.name}`);
console.log(`📦 Ejecutando desde: ${adrianBotDir}`);

// Cambiar al directorio del bot y ejecutar start.js
try {
  process.chdir(adrianBotDir);
  console.log(`🚀 Ejecutando: node start.js`);
  console.log('========================================\n');
  require(path.join(adrianBotDir, 'start.js'));
} catch (error) {
  console.error('❌ ERROR al ejecutar el bot:');
  console.error(error.message);
  process.exit(1);
}

