import { ethers } from 'ethers';
import * as fs from 'fs';
import * as path from 'path';
import { config, validateConfig } from './config/env';
import { logger } from './utils/logger';
import { BotStatus } from './utils/status';
import { PoolDiscoveryService } from './services/PoolDiscoveryService';
import { PriceComparisonService } from './services/PriceComparisonService';
import { SwapService } from './services/SwapService';
import { ArbitrageService } from './services/ArbitrageService';
import { EmergencyModeService } from './services/EmergencyModeService';
import { PriceChangeMonitor } from './services/PriceChangeMonitor';

// VERIFICACIÓN INMEDIATA: Detectar si estamos ejecutando el bot incorrecto ANTES de cualquier otra cosa
(function immediateBotCheck() {
  try {
    const workingDir = process.cwd();
    const scriptPath = process.argv[1] || __filename;
    
    // #region agent log
    fetch('http://127.0.0.1:7242/ingest/7e4412d0-d04a-4fec-a842-10e1a74a267c',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'bot.ts:17',message:'Bot check start',data:{workingDir,scriptPath,__dirname,argv:process.argv},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'A'})}).catch(()=>{});
    // #endregion
    
    console.log('========================================');
    console.log('🔍 VERIFICACIÓN DE BOT');
    console.log('========================================');
    console.log(`Directorio de trabajo: ${workingDir}`);
    console.log(`Script ejecutado: ${scriptPath}`);
    console.log('========================================\n');
    
    // Verificar si estamos en el directorio correcto
    const adrianBotDir = path.join(workingDir, 'adrian-arbitrage-bot');
    const rootPackagePath = path.join(workingDir, 'package.json');
    const adrianPackagePath = path.join(adrianBotDir, 'package.json');
    const relativePackagePath = path.resolve(__dirname, '../package.json');
    
    const isInAdrianDir = fs.existsSync(rootPackagePath) && 
                          fs.existsSync(path.join(workingDir, 'src', 'bot.ts'));
    const isInRootWithAdrian = fs.existsSync(adrianBotDir) && 
                               fs.existsSync(adrianPackagePath);
    const rootHasPackage = fs.existsSync(rootPackagePath);
    
    // #region agent log
    fetch('http://127.0.0.1:7242/ingest/7e4412d0-d04a-4fec-a842-10e1a74a267c',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'bot.ts:28',message:'Directory check',data:{isInAdrianDir,isInRootWithAdrian,rootHasPackage,rootPackagePath,adrianPackagePath,relativePackagePath},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'B'})}).catch(()=>{});
    // #endregion
    
    let packageJson: any;
    let packagePath: string;
    let detectionMethod = '';
    
    // Prioridad 1: Si estamos en el directorio adrian-arbitrage-bot
    if (isInAdrianDir) {
      packagePath = rootPackagePath;
      packageJson = require(packagePath);
      detectionMethod = 'direct';
    }
    // Prioridad 2: Si estamos en la raíz y existe adrian-arbitrage-bot
    else if (isInRootWithAdrian) {
      packagePath = adrianPackagePath;
      packageJson = require(packagePath);
      detectionMethod = 'root-with-adrian';
    }
    // Prioridad 3: Intentar desde el directorio actual
    else {
      packagePath = rootPackagePath;
      if (fs.existsSync(packagePath)) {
        packageJson = require(packagePath);
        detectionMethod = 'root-fallback';
      } else {
        // Último intento: buscar relativamente
        try {
          packagePath = relativePackagePath;
          packageJson = require(packagePath);
          detectionMethod = 'relative';
        } catch {
          console.error('❌ No se pudo encontrar package.json');
          return;
        }
      }
    }
    
    // #region agent log
    fetch('http://127.0.0.1:7242/ingest/7e4412d0-d04a-4fec-a842-10e1a74a267c',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'bot.ts:62',message:'Package detected',data:{packagePath,detectionMethod,packageName:packageJson?.name},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'C'})}).catch(()=>{});
    // #endregion
    
    const packageName = packageJson?.name;
    
    // #region agent log
    fetch('http://127.0.0.1:7242/ingest/7e4412d0-d04a-4fec-a842-10e1a74a267c',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'bot.ts:66',message:'Package name check',data:{packageName,expectedName:'adrian-arbitrage-bot',isNFTBot:packageName==='nft-arbitrage-bot'||packageName?.includes('nft')},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'D'})}).catch(()=>{});
    // #endregion
    
    console.log(`Package encontrado: ${packagePath}`);
    console.log(`Package name: ${packageName}`);
    console.log(`Método de detección: ${detectionMethod}`);
    console.log('========================================\n');
    
    // Si detectamos el NFT bot, fallar INMEDIATAMENTE
    if (packageName === 'nft-arbitrage-bot' || (packageName && packageName.includes('nft'))) {
      // #region agent log
      fetch('http://127.0.0.1:7242/ingest/7e4412d0-d04a-4fec-a842-10e1a74a267c',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'bot.ts:72',message:'NFT bot detected - ERROR',data:{packageName,packagePath,workingDir,scriptPath},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'E'})}).catch(()=>{});
      // #endregion
      console.error('\n========================================');
      console.error('❌ ERROR CRÍTICO: DETECTADO NFT BOT');
      console.error('========================================');
      console.error(`Package name: ${packageName}`);
      console.error(`Package path: ${packagePath}`);
      console.error(`Directorio de trabajo: ${workingDir}`);
      console.error(`Script ejecutado: ${scriptPath}`);
      console.error('========================================');
      console.error('Railway está ejecutando el código del NFT bot.');
      console.error('\nSOLUCIÓN EN RAILWAY:');
      console.error('1. Settings → Build → Build Command:');
      console.error('   cd adrian-arbitrage-bot && npm install && npm run build');
      console.error('2. Settings → Deploy → Start Command:');
      console.error('   cd adrian-arbitrage-bot && npm run start:prod');
      console.error('3. Settings → Source → Root Directory: VACÍO');
      console.error('4. Settings → Build → Watch Paths: adrian-arbitrage-bot/**');
      console.error('========================================\n');
      process.exit(1);
    }
    
    // Verificar que el package name sea correcto
    if (packageName !== 'adrian-arbitrage-bot') {
      // #region agent log
      fetch('http://127.0.0.1:7242/ingest/7e4412d0-d04a-4fec-a842-10e1a74a267c',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'bot.ts:95',message:'Wrong package name - ERROR',data:{packageName,expectedName:'adrian-arbitrage-bot',packagePath},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'F'})}).catch(()=>{});
      // #endregion
      console.error('\n========================================');
      console.error('❌ ERROR: Package name incorrecto');
      console.error('========================================');
      console.error(`Esperado: adrian-arbitrage-bot`);
      console.error(`Encontrado: ${packageName}`);
      console.error(`Package path: ${packagePath}`);
      console.error('========================================\n');
      process.exit(1);
    }
    
    // #region agent log
    fetch('http://127.0.0.1:7242/ingest/7e4412d0-d04a-4fec-a842-10e1a74a267c',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'bot.ts:105',message:'Bot check passed',data:{packageName,packagePath,detectionMethod},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'G'})}).catch(()=>{});
    // #endregion
    
    console.log('✅ Verificación de bot correcta\n');
  } catch (error: any) {
    console.error('❌ Error en verificación de bot:', error.message);
    // Continuar para que la validación principal lo detecte
  }
})();

async function executeArbitrageCycle(
  discoveryService: PoolDiscoveryService,
  priceComparisonService: PriceComparisonService,
  arbitrageService: ArbitrageService,
  botStatus: BotStatus,
  emergencyMode: EmergencyModeService,
  priceChangeMonitor: PriceChangeMonitor,
  provider: ethers.Provider,
  signer: ethers.Wallet
) {
  try {
    botStatus.recordCheck();
    logger.info('=== ADRIAN ARBITRAGE BOT - CICLO DE ARBITRAJE ===\n');
    
    // Verificar estado del modo de emergencia
    const emergencyStatus = emergencyMode.getStatusInfo();
    if (emergencyStatus.isActive) {
      logger.warn('🚨 MODO DE EMERGENCIA ACTIVO - Monitoreando pero sin ejecutar trades', {
        consecutiveFailures: emergencyStatus.consecutiveFailures,
        lastFailureReason: emergencyStatus.lastFailureReason,
        totalFailures: emergencyStatus.totalFailures,
        message: 'Usa el script de reactivación para continuar con las transacciones.',
      });
      // Continuar monitoreando pero no ejecutar trades
    } else if (emergencyStatus.consecutiveFailures > 0) {
      logger.warn('⚠️ Advertencia: Fallos consecutivos detectados', {
        consecutiveFailures: emergencyStatus.consecutiveFailures,
        maxConsecutiveFailures: emergencyStatus.maxConsecutiveFailures,
        lastFailureReason: emergencyStatus.lastFailureReason,
      });
    }
    
    // Obtener datos actualizados de pools
    logger.info('--- Usando pools pre-configurados ---');
    const poolServices = discoveryService.getPoolServices();
    
    // Actualizar PriceComparisonService con pool services actualizados
    const updatedPriceService = new PriceComparisonService(provider, poolServices);
    
    // Actualizar PriceChangeMonitor con pool services actualizados (mantener precios base)
    (priceChangeMonitor as any).poolServices = poolServices;
    
    // Monitorear cambios de precio significativos
    logger.info('--- Monitoreando cambios de precio ---');
    const priceChanges = await priceChangeMonitor.detectSignificantPriceChanges();
    
    // Log detallado de precios actuales para debug
    logger.debug('Precios actuales de pools', {
      pools: Array.from(poolServices.keys()).map(poolId => {
        const poolService = poolServices.get(poolId);
        if (poolService) {
          const poolInfo = (poolService as any).poolInfo;
          return {
            poolId,
            token0: poolInfo?.config?.token0?.substring(0, 10) + '...',
            token1: poolInfo?.config?.token1?.substring(0, 10) + '...',
          };
        }
        return { poolId };
      }),
    });
    
    let opportunities: any[] = [];
    
    // Si hay cambios significativos, buscar oportunidades con márgenes más permisivos
    if (priceChanges.size > 0) {
      logger.info(`⚠️ Detectados ${priceChanges.size} cambio(s) de precio significativo(s)`, {
        pools: Array.from(priceChanges.keys()),
      });
      
      // Para cada pool con cambio significativo, buscar oportunidades
      for (const [poolId, changeInfo] of priceChanges.entries()) {
        logger.info(`Buscando oportunidades después de cambio en ${poolId}`, {
          changePercent: `${changeInfo.changePercent.toFixed(2)}%`,
          direction: changeInfo.direction,
        });
        
        const opps = await priceChangeMonitor.detectArbitrageAfterPriceChange(
          poolId,
          updatedPriceService
        );
        opportunities.push(...opps);
      }
    }
    
    // También detectar oportunidades normales (por si hay oportunidades que no fueron causadas por cambios recientes)
    logger.info('--- Detectando oportunidades estándar ---');
    const standardOpportunities = await updatedPriceService.detectOpportunities(config.minProfitMarginBps);
    
    // Combinar oportunidades, priorizando las detectadas después de cambios de precio
    opportunities = [...opportunities, ...standardOpportunities];
    
    // Eliminar duplicados (mismo buyPool y sellPool)
    const uniqueOpportunities = opportunities.filter((opp, index, self) =>
      index === self.findIndex((o) => 
        o.buyPool.config.id === opp.buyPool.config.id &&
        o.sellPool.config.id === opp.sellPool.config.id
      )
    );
    
    opportunities = uniqueOpportunities;
    
    logger.info(`Oportunidades detectadas: ${opportunities.length}`);
    
    if (opportunities.length === 0) {
      logger.info('No hay oportunidades rentables en este momento');
      return;
    }
    
    // Filtrar por margen mínimo - usar margen reducido si hay cambios de precio
    const effectiveMinMargin = priceChanges.size > 0
      ? Math.max(25, config.minProfitMarginBps / 4) // Reducir a 25% del original si hay cambios
      : config.minProfitMarginBps;
    
    logger.info(`Filtrando oportunidades con margen mínimo: ${effectiveMinMargin} bps (${effectiveMinMargin / 100}%)`, {
      originalMargin: config.minProfitMarginBps,
      priceChangesDetected: priceChanges.size,
    });
    
    const profitableOpportunities = updatedPriceService.filterByMinMargin(
      opportunities,
      effectiveMinMargin
    );
    
    logger.info(`Oportunidades rentables: ${profitableOpportunities.length}`, {
      totalDetected: opportunities.length,
      afterFilter: profitableOpportunities.length,
      minMarginUsed: effectiveMinMargin,
    });
    
    if (profitableOpportunities.length === 0) {
      // Log detallado de por qué no hay oportunidades
      if (opportunities.length > 0) {
        logger.warn('Oportunidades detectadas pero no rentables', {
          totalOpportunities: opportunities.length,
          bestOpportunity: opportunities[0] ? {
            buyPool: opportunities[0].buyPool.config.id,
            sellPool: opportunities[0].sellPool.config.id,
            estimatedProfit: ethers.formatEther(opportunities[0].estimatedProfit),
            estimatedAmountIn: ethers.formatEther(opportunities[0].estimatedAmountIn),
            profitMarginBps: Number((opportunities[0].estimatedProfit * 10000n) / opportunities[0].estimatedAmountIn),
            requiredMargin: effectiveMinMargin,
          } : null,
        });
      } else {
        logger.info('No hay oportunidades detectadas en este momento');
      }
      return;
    }
    
    // Verificar si se pueden ejecutar trades (modo de emergencia)
    if (!emergencyMode.canExecuteTrades()) {
      logger.warn('🚨 Modo de emergencia activo - Oportunidades detectadas pero trades pausados', {
        opportunitiesDetected: profitableOpportunities.length,
        bestOpportunityProfit: ethers.formatEther(profitableOpportunities[0].estimatedProfit),
      });
      return;
    }
    
    // Ejecutar la mejor oportunidad
    const bestOpportunity = profitableOpportunities[0];
    
    // Mostrar información de tamaño de trade si está disponible
    const tradeSizeInfo = (bestOpportunity as any).tradeSizeInfo;
    if (tradeSizeInfo) {
      logger.info('Información de tamaño de trade', {
        strategy: tradeSizeInfo.strategy,
        optimalAdrianAmount: ethers.formatEther(BigInt(tradeSizeInfo.optimalAdrianAmount)),
        minTradeAmount: ethers.formatEther(BigInt(tradeSizeInfo.minTradeAmount)),
        maxTradeAmount: ethers.formatEther(BigInt(tradeSizeInfo.maxTradeAmount)),
        riskLevel: tradeSizeInfo.riskLevel,
      });
    }
    
    logger.info('Ejecutando mejor oportunidad', {
      buyPool: bestOpportunity.buyPool.config.id,
      sellPool: bestOpportunity.sellPool.config.id,
      estimatedProfit: ethers.formatEther(bestOpportunity.estimatedProfit),
      estimatedAmountIn: bestOpportunity.buyPool.config.token1.toLowerCase() === config.wethAddress.toLowerCase()
        ? ethers.formatEther(bestOpportunity.estimatedAmountIn)
        : ethers.formatUnits(bestOpportunity.estimatedAmountIn, 6),
    });
    
    botStatus.recordOpportunity();
    
    const result = await arbitrageService.executeArbitrage(bestOpportunity);
    
    logger.info('Arbitraje ejecutado exitosamente', {
      realProfit: ethers.formatEther(result.realProfit),
      txHash1: result.txHash1,
      txHash2: result.txHash2,
    });
    
    botStatus.recordExecution(result.realProfit, bestOpportunity.estimatedAmountIn);
    
    logger.info('\n=== CICLO COMPLETADO ===');
    
  } catch (error: any) {
    logger.error('Error en ciclo de arbitraje', {
      error: error.message,
      stack: error.stack,
    });
    botStatus.recordError(error.message);
    
    // Si el error es por modo de emergencia, no es un error crítico
    if (error.message?.includes('MODO DE EMERGENCIA')) {
      logger.info('El bot continuará monitoreando pero no ejecutará trades hasta reactivación');
    }
  }
}

async function main() {
  try {
    // VERIFICACIÓN CRÍTICA: Asegurar que estamos ejecutando el bot correcto
    // Esta validación previene que Railway ejecute el código del NFT bot por error
    const workingDir = process.cwd();
    const expectedDirName = 'adrian-arbitrage-bot';
    
    // Verificar que estamos en el directorio correcto
    const isInCorrectDir = workingDir.includes(expectedDirName) || 
                          fs.existsSync(path.join(workingDir, 'package.json')) && 
                          fs.existsSync(path.join(workingDir, 'src', 'bot.ts'));
    
    let packageJson: any;
    try {
      // Intentar leer package.json desde el directorio actual o relativo
      const packagePath = path.join(workingDir, 'package.json');
      if (fs.existsSync(packagePath)) {
        packageJson = require(packagePath);
      } else {
        packageJson = require('../package.json');
      }
    } catch (error) {
      console.error('❌ ERROR CRÍTICO: No se pudo leer package.json');
      console.error('Esto indica que Railway está ejecutando el código desde el directorio incorrecto.');
      console.error('Directorio de trabajo:', workingDir);
      console.error('Verifica que el Start Command en Railway sea: cd adrian-arbitrage-bot && npm run start:prod');
      process.exit(1);
    }
    
    const packageName = packageJson.name;
    const expectedName = 'adrian-arbitrage-bot';
    
    // Verificar que NO estamos ejecutando el NFT bot
    if (packageName === 'nft-arbitrage-bot' || packageName?.includes('nft')) {
      console.error('========================================');
      console.error('❌ ERROR CRÍTICO: DETECTADO NFT BOT EN LUGAR DE ADRIAN BOT');
      console.error('========================================');
      console.error(`Package name detectado: ${packageName}`);
      console.error('Directorio de trabajo:', workingDir);
      console.error('========================================');
      console.error('Railway está ejecutando el código del NFT bot en lugar del Adrian bot.');
      console.error('SOLUCIÓN: Verifica la configuración del servicio "adrian-arbitrage-bot" en Railway:');
      console.error('1. Ve a Settings → Source → Root Directory: DEBE ESTAR VACÍO');
      console.error('2. Ve a Settings → Build → Build Command: cd adrian-arbitrage-bot && npm install && npm run build');
      console.error('3. Ve a Settings → Deploy → Start Command: cd adrian-arbitrage-bot && npm run start:prod');
      console.error('4. Asegúrate de que el servicio se llama "adrian-arbitrage-bot" y NO "nft-arbitrage-bot"');
      console.error('========================================');
      process.exit(1);
    }
    
    if (packageName !== expectedName) {
      console.error('========================================');
      console.error('❌ ERROR CRÍTICO: BOT INCORRECTO DETECTADO');
      console.error('========================================');
      console.error(`Package name esperado: ${expectedName}`);
      console.error(`Package name detectado: ${packageName}`);
      console.error('Directorio de trabajo:', workingDir);
      console.error('========================================');
      console.error('Railway está ejecutando el código del bot incorrecto.');
      console.error('Verifica la configuración del servicio en Railway:');
      console.error('1. Root Directory debe estar VACÍO');
      console.error('2. Start Command debe ser: cd adrian-arbitrage-bot && npm run start:prod');
      console.error('3. Build Command debe ser: cd adrian-arbitrage-bot && npm install && npm run build');
      console.error('========================================');
      process.exit(1);
    }
    
    // Identificación explícita del bot
    console.log('========================================');
    console.log('🚀 ADRIAN ARBITRAGE BOT - INICIANDO');
    console.log('========================================');
    console.log('✓ Verificación de bot correcto: PASADA');
    console.log('Directorio de trabajo:', process.cwd());
    console.log('Package name:', packageName);
    console.log('Archivo ejecutado:', __filename);
    console.log('========================================\n');
    
    logger.info('========================================');
    logger.info('🚀 ADRIAN ARBITRAGE BOT - INICIANDO');
    logger.info('========================================');
    logger.info('✓ Verificación de bot correcto: PASADA', {
      packageName,
      workingDirectory: process.cwd(),
      executedFile: __filename,
    });
    
    // Validar configuración
    validateConfig();
    logger.info('✓ Configuración validada');
    
    // Verificar modo
    if (config.mode === 'test') {
      logger.warn('⚠️  Bot está en modo TEST. Cambia EXECUTION_MODE=production para ejecutar operaciones reales');
      logger.warn('Usa "npm run test:detect" para modo de pruebas');
      process.exit(0);
    }
    
    // Crear provider y signer
    const provider = new ethers.JsonRpcProvider(config.rpcUrl);
    const signer = new ethers.Wallet(config.privateKey, provider);
    logger.info('✓ Provider y signer inicializados', { address: signer.address });
    
    // Inicializar servicios
    const discoveryService = new PoolDiscoveryService(provider);
    const poolServices = discoveryService.getPoolServices();
    const priceComparisonService = new PriceComparisonService(provider, poolServices);
    const swapService = new SwapService(provider, signer, poolServices);
    
    // Inicializar modo de emergencia
    const maxConsecutiveFailures = parseInt(process.env.MAX_CONSECUTIVE_FAILURES || '10', 10);
    const emergencyMode = new EmergencyModeService(maxConsecutiveFailures);
    await emergencyMode.initialize();
    
    const arbitrageService = new ArbitrageService(provider, signer, swapService, emergencyMode);
    const botStatus = new BotStatus();
    
    // Descubrir pools inicial
    logger.info('Descubriendo pools iniciales...');
    await discoveryService.discoverAllPools();
    
    // Inicializar monitor de cambios de precio
    const priceChangeThreshold = parseFloat(process.env.PRICE_CHANGE_THRESHOLD || '0.5'); // 0.5% por defecto
    const priceChangeMonitor = new PriceChangeMonitor(provider, poolServices, priceChangeThreshold);
    await priceChangeMonitor.initializePrices();
    logger.info(`Monitor de cambios de precio inicializado (umbral: ${priceChangeThreshold}%)`);
    
    // Manejar señales de cierre graceful
    let shouldStop = false;
    process.on('SIGINT', () => {
      logger.info('Señal SIGINT recibida, deteniendo bot...');
      shouldStop = true;
    });
    process.on('SIGTERM', () => {
      logger.info('Señal SIGTERM recibida, deteniendo bot...');
      shouldStop = true;
    });
    
    logger.info(`Iniciando loop principal (intervalo: ${config.executionIntervalSeconds}s)`);
    logger.info('💡 Presiona Ctrl+C para detener el bot\n');
    
    // Loop principal
    while (!shouldStop) {
      try {
        await executeArbitrageCycle(
          discoveryService,
          priceComparisonService,
          arbitrageService,
          botStatus,
          emergencyMode,
          priceChangeMonitor,
          provider,
          signer
        );
        
        // Mostrar estadísticas cada 10 ciclos
        if (botStatus.getStats().totalChecks % 10 === 0) {
          botStatus.printStatus();
        }
        
      } catch (error: any) {
        logger.error('Error en loop principal', { error: error.message });
        botStatus.recordError(error.message);
      }
      
      if (!shouldStop) {
        logger.debug(`Esperando ${config.executionIntervalSeconds} segundos antes de la siguiente verificación...`);
        await new Promise(resolve => setTimeout(resolve, config.executionIntervalSeconds * 1000));
      }
    }
    
    logger.info('Bot deteniéndose...');
    
    // Mostrar estadísticas finales
    logger.info('\n=== ESTADÍSTICAS FINALES ===');
    botStatus.printStatus();
    logger.info('=== Bot detenido ===');
    
  } catch (error: any) {
    console.error('❌ ERROR FATAL:', error.message);
    console.error('Stack:', error.stack);
    logger.error('Error fatal en bot', { error: error.message, stack: error.stack });
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error('❌ ERROR NO MANEJADO:', error);
    logger.error('Error no manejado', { error });
    process.exit(1);
  });
}

