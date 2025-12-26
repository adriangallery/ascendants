import { ethers } from 'ethers';
import { config, validateConfig } from '../config/env';
import { logger } from '../utils/logger';
import { PoolDiscoveryService } from '../services/PoolDiscoveryService';
import { SwapService } from '../services/SwapService';
import { ArbitrageService } from '../services/ArbitrageService';
import { EmergencyModeService } from '../services/EmergencyModeService';
import { ArbitrageOpportunity, PoolInfo } from '../types';

/**
 * Prueba forzada de arbitraje para medir slippage real aunque sea con pérdida.
 * Ejecuta buy en v4 y sell en v2 con un monto pequeño de ETH.
 */
async function main() {
  // Monto de entrada en ETH (pequeño para limitar riesgo)
  const amountInEth = process.env.FORCE_AMOUNT_ETH
    || process.argv[2]
    || '0.00002';
  const buyPoolId = process.env.BUY_POOL || 'v4-eth-adrian';
  const sellPoolId = process.env.SELL_POOL || 'v2-eth-adrian';

  logger.warn('⚠️ Prueba forzada: se ejecutarán swaps reales aunque haya pérdida');
  logger.warn(`Monto de entrada: ${amountInEth} ETH`);

  // Validar configuración
  validateConfig();

  const provider = new ethers.JsonRpcProvider(config.rpcUrl);
  const signer = new ethers.Wallet(config.privateKey, provider);

  logger.info('Dirección usada', { address: signer.address });

  // Descubrir pools y obtener servicios
  const discoveryService = new PoolDiscoveryService(provider);
  await discoveryService.discoverAllPools();
  const poolServices = discoveryService.getPoolServices();

  const buyPoolService = poolServices.get(buyPoolId);
  const sellPoolService = poolServices.get(sellPoolId);

  if (!buyPoolService || !sellPoolService) {
    throw new Error('No se encontraron los pool services requeridos');
  }

  const buyPoolInfo = (buyPoolService as any).poolInfo as PoolInfo;
  const sellPoolInfo = (sellPoolService as any).poolInfo as PoolInfo;

  const amountIn = ethers.parseEther(amountInEth);

  // Construir oportunidad mínima, sin filtros de margen, con amountOutMin=0 para no revertir por slippage
  const forcedOpp: ArbitrageOpportunity = {
    id: `forced-${Date.now()}`,
    buyPool: buyPoolInfo,
    sellPool: sellPoolInfo,
    estimatedAmountIn: amountIn,
    estimatedAmountOut: 0n,
    estimatedProfit: 0n,
    estimatedGas: 0n,
    estimatedSlippage: 0, // se usa solo para logs/cálculo de minOut (que será 0)
    minProfitMarginBps: 0,
    timestamp: Date.now(),
  };

  const swapService = new SwapService(provider, signer, poolServices);

  const maxConsecutiveFailures = parseInt(process.env.MAX_CONSECUTIVE_FAILURES || '10', 10);
  const emergencyMode = new EmergencyModeService(maxConsecutiveFailures);
  await emergencyMode.initialize();

  const arbitrageService = new ArbitrageService(provider, signer, swapService, emergencyMode);

  logger.info('Ejecutando prueba forzada de arbitraje', {
    buyPool: buyPoolId,
    sellPool: sellPoolId,
    amountIn: amountInEth,
  });

  const result = await arbitrageService.executeArbitrage(forcedOpp);

  logger.info('Resultado de la prueba forzada', {
    realProfit: ethers.formatEther(result.realProfit),
    realGas: ethers.formatEther(result.realGas),
    txHash1: result.txHash1,
    txHash2: result.txHash2,
  });
}

if (require.main === module) {
  main().catch((error) => {
    logger.error('Error en prueba forzada', { error: error.message, stack: error.stack });
    process.exit(1);
  });
}

