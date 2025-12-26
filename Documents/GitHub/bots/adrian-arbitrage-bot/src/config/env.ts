import dotenv from 'dotenv';

// Cargar variables de entorno desde archivo sólo en desarrollo; en Railway las expone el entorno
if (process.env.NODE_ENV !== 'production') {
  dotenv.config({ path: '.env.local' });
} else {
  dotenv.config(); // no hace daño si no existe archivo
}

// Debug: Log de variables de entorno (sin valores sensibles)
if (process.env.NODE_ENV !== 'production' || process.env.RAILWAY_ENVIRONMENT) {
  console.log('🔍 Debug: Variables de entorno detectadas:');
  console.log('  PRIVATE_KEY:', process.env.PRIVATE_KEY ? `[${process.env.PRIVATE_KEY.substring(0, 6)}...] (${process.env.PRIVATE_KEY.length} chars)` : 'NO DEFINIDA');
  console.log('  RPC_URL:', process.env.RPC_URL ? '[DEFINIDA]' : 'NO DEFINIDA');
}

export const config = {
  // Wallet (REQUERIDO)
  privateKey: (() => {
    const rawKey = process.env.PRIVATE_KEY || '';
    const has0x = rawKey.startsWith('0x');
    return has0x ? rawKey : (rawKey ? '0x' + rawKey : '');
  })(),
  
  // RPC (REQUERIDO)
  rpcUrl: process.env.RPC_URL || '',
  
  // Token Addresses
  adrianTokenAddress: process.env.ADRIAN_TOKEN_ADDRESS || '0x7E99075Ce287F1cF8cBCAaa6A1C7894e404fD7Ea',
  wethAddress: process.env.WETH_ADDRESS || '0x4200000000000000000000000000000000000006',
  usdcAddress: process.env.USDC_ADDRESS || '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
  
  // Uniswap Routers (oficiales en Base)
  uniswapV2Router: process.env.UNISWAP_V2_ROUTER || '0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24',
  uniswapV3Router: process.env.UNISWAP_V3_ROUTER || '0x2626664c2603336E57B271c5C0b26F421741e481',
  
  // Pool V4 (existente)
  uniswapV4PoolManager: process.env.UNISWAP_V4_POOL_MANAGER || '0x498581fF718922c3f8e6A244956aF099B2652b2b',
  uniswapV4PoolAddress: process.env.UNISWAP_V4_POOL_ADDRESS || '', // Pool ID (hash del PoolKey)
  adrianSwapperAddress: process.env.ADRIAN_SWAPPER_ADDRESS || '0xA4542337205a9C129C01352CD204567bB0E91878', // AdrianSwapper tiene función swap() que es el SwapHelper
  
  // Bot Configuration
  minProfitMarginBps: parseInt(process.env.MIN_PROFIT_MARGIN_BPS || '300', 10), // 3% default
  executionIntervalSeconds: parseInt(process.env.EXECUTION_INTERVAL_SECONDS || '60', 10),
  maxSlippageBps: parseInt(process.env.MAX_SLIPPAGE_BPS || '100', 10), // 1% base, ajustado dinámicamente
  minLiquidityThreshold: process.env.MIN_LIQUIDITY_THRESHOLD || '1000', // ADRIAN mínimo en pool
  
  // Price Change Monitoring
  priceChangeThreshold: parseFloat(process.env.PRICE_CHANGE_THRESHOLD || '0.5'), // 0.5% por defecto
  
  // Logging
  logLevel: process.env.LOG_LEVEL || 'info',
  
  // Execution Mode
  mode: (process.env.EXECUTION_MODE || 'test') as 'test' | 'production',
  
  // Emergency Mode
  maxConsecutiveFailures: parseInt(process.env.MAX_CONSECUTIVE_FAILURES || '10', 10),
  
  // Trade Size Strategy
  tradeSizeStrategy: (process.env.TRADE_SIZE_STRATEGY || 'optimal') as 'min' | 'optimal' | 'max' | 'adaptive',
  tradeSizeMargins: {
    // Ajustados basándose en resultados reales:
    // - Slippage real fue mucho menor que el estimado
    // - Gas real fue 99.4% menor que el estimado
    // - Oportunidades rentables no fueron detectadas
    maxSlippageBps: parseInt(process.env.MAX_SLIPPAGE_BPS || '1000', 10), // 10% default (aumentado de 5%)
    minProfitMarginBps: parseInt(process.env.MIN_PROFIT_MARGIN_BPS || '50', 10), // 0.5% default (reducido de 1%)
    liquidityUtilizationRatio: parseFloat(process.env.LIQUIDITY_UTILIZATION_RATIO || '0.15'), // 15% default (aumentado de 10%)
    gasCostBuffer: parseFloat(process.env.GAS_COST_BUFFER || '2.0'), // 100% buffer default (aumentado de 1.5)
  },
  
  // Network-specific gas settings
  network: process.env.NETWORK || 'base', // 'base' | 'ethereum' | 'arbitrum' | etc.
  baseGasPrice: process.env.BASE_GAS_PRICE || '1500000', // 1.5 gwei default for Base (basado en resultados reales)
};

// Validación de variables requeridas
export function validateConfig(): void {
  const missing: string[] = [];
  
  if (!config.privateKey) missing.push('PRIVATE_KEY');
  if (!config.rpcUrl) missing.push('RPC_URL');
  if (!config.adrianTokenAddress) missing.push('ADRIAN_TOKEN_ADDRESS');
  
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
}

