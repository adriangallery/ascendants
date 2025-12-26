import { ethers } from 'ethers';
import { ArbitrageOpportunity, SwapParams } from '../types';
import { SwapService } from './SwapService';
import { logger } from '../utils/logger';
import { GasEstimator } from '../utils/gas';
import { EmergencyModeService, FailureReason } from './EmergencyModeService';

/**
 * Servicio para ejecutar operaciones de arbitraje completas
 */
export class ArbitrageService {
  private provider: ethers.Provider;
  private signer: ethers.Wallet;
  private swapService: SwapService;
  private gasEstimator: GasEstimator;
  private emergencyMode: EmergencyModeService | null;

  constructor(
    provider: ethers.Provider,
    signer: ethers.Wallet,
    swapService: SwapService,
    emergencyMode?: EmergencyModeService
  ) {
    this.provider = provider;
    this.signer = signer;
    this.swapService = swapService;
    this.gasEstimator = new GasEstimator(provider);
    this.emergencyMode = emergencyMode || null;
  }

  /**
   * Ejecuta una operación de arbitraje completa
   */
  async executeArbitrage(opportunity: ArbitrageOpportunity): Promise<{
    txHash1: string;
    txHash2: string;
    realProfit: bigint;
    realGas: bigint;
  }> {
    // Verificar modo de emergencia
    if (this.emergencyMode?.isEmergencyModeActive()) {
      const status = this.emergencyMode.getStatusInfo();
      throw new Error(
        `🚨 MODO DE EMERGENCIA ACTIVO: ${status.consecutiveFailures} fallos consecutivos. ` +
        `Último fallo: ${status.lastFailureReason}. ` +
        `Las transacciones están pausadas. Usa el script de reactivación para continuar.`
      );
    }

    try {
      // Balances antes de iniciar (para medir delta real)
      const ethBeforeAll = await this.provider.getBalance(this.signer.address);
      const adrianBeforeAll = await this.getTokenBalance(opportunity.buyPool.config.token0);

      logger.info('Ejecutando arbitraje', {
        buyPool: opportunity.buyPool.config.id,
        sellPool: opportunity.sellPool.config.id,
        estimatedProfit: ethers.formatEther(opportunity.estimatedProfit),
      });

      // Guardas previas: estimación de profit vs gas/slippage
      if (opportunity.estimatedProfit <= 0n) {
        throw new Error('Profit estimado <= 0, abortando ejecución');
      }
      const estGasCost = opportunity.estimatedGas && opportunity.estimatedGas > 0n
        ? opportunity.estimatedGas
        : 0n;
      const gasPriceForCheck = await this.gasEstimator.getGasPrice();
      const estGasEth = estGasCost * gasPriceForCheck;
      if (estGasCost > 0n && opportunity.estimatedProfit <= estGasEth) {
        throw new Error('Profit estimado no cubre gas estimado, abortando');
      }

      // Verificar balances antes de ejecutar
      await this.verifyBalances(opportunity);

      // Paso 1: Swap de compra (comprar ADRIAN barato)
      // Para V4 pools, necesitamos estimar primero cuánto ADRIAN recibiremos
      // para calcular amountOutMin correctamente (especialmente para buyAdrianExactOutput)
      let amountOutMin = 0n;
      if (opportunity.buyPool.config.type === 'v4') {
        // Para V4, necesitamos obtener el pool service y estimar el swap
        // El SwapService tiene acceso a los pool services, pero no los expone públicamente
        // Por ahora, usamos una estimación conservadora basada en el precio
        // El SwapService calculará el amountOut correcto cuando ejecute el swap
        amountOutMin = 0n; // Se calculará en SwapService usando estimateSwap
      } else {
        // Para V2/V3, podemos usar el cálculo normal
        // Pero necesitamos estimar primero el amountOut
        // Por simplicidad, usamos 0 y dejamos que SwapService lo calcule
        amountOutMin = 0n;
      }
      
      const effectiveSlippageBpsBuy = this.getEffectiveSlippageBps(
        opportunity,
        'buy'
      );
      const buyParams: SwapParams = {
        tokenIn: opportunity.buyPool.config.token1, // ETH/USDC
        tokenOut: opportunity.buyPool.config.token0, // ADRIAN
        amountIn: opportunity.estimatedAmountIn,
        amountOutMin: amountOutMin, // Se calculará en SwapService si es necesario
        poolId: opportunity.buyPool.config.id,
        poolType: opportunity.buyPool.config.type,
      };

      logger.info('Ejecutando swap de compra...');
      const buyTx = await this.swapService.executeSwap(buyParams);
      logger.info('Swap de compra enviado', { hash: buyTx.hash });

      // Esperar confirmación
      const buyReceipt = await buyTx.wait();
      if (!buyReceipt) {
        throw new Error('Buy transaction receipt is null');
      }
      logger.info('Swap de compra confirmado', {
        blockNumber: buyReceipt.blockNumber,
        status: buyReceipt.status,
      });

      // Obtener cantidad real recibida (delta de balance)
      const buyBlock = buyReceipt.blockNumber;
      const adrianBeforeBlock = await this.getTokenBalanceAt(
        opportunity.buyPool.config.token0,
        buyBlock > 0 ? buyBlock - 1 : buyBlock
      );
      const adrianAfterBlock = await this.getTokenBalanceAt(
        opportunity.buyPool.config.token0,
        buyBlock
      );
      const adrianAfterBuy = await this.getTokenBalance(opportunity.buyPool.config.token0);
      const adrianFromLogs = this.getAdrianFromLogs(buyReceipt, opportunity.buyPool.config.token0);

      const deltaByBlock = adrianAfterBlock > adrianBeforeBlock
        ? adrianAfterBlock - adrianBeforeBlock
        : 0n;
      const deltaRuntime = adrianAfterBuy > adrianBeforeAll
        ? adrianAfterBuy - adrianBeforeAll
        : 0n;

      const adrianReceived = adrianFromLogs > 0n
        ? adrianFromLogs
        : (deltaByBlock > 0n ? deltaByBlock : deltaRuntime);

      logger.info('Balances ADRIAN (delta)', {
        adrianBeforeAll: adrianBeforeAll.toString(),
        adrianBeforeBlock: adrianBeforeBlock.toString(),
        adrianAfterBlock: adrianAfterBlock.toString(),
        adrianAfterBuy: adrianAfterBuy.toString(),
        deltaByBlock: deltaByBlock.toString(),
        deltaRuntime: deltaRuntime.toString(),
        adrianFromLogs: adrianFromLogs.toString(),
        adrianReceived: adrianReceived.toString(),
      });

      // Paso 2: Swap de venta (vender ADRIAN caro)
      if (opportunity.estimatedAmountOut <= 0n) {
        throw new Error('estimatedAmountOut es 0, abortando');
      }
      const effectiveSlippageBpsSell = this.getEffectiveSlippageBps(
        opportunity,
        'sell'
      );
      const minOut = this.calculateMinAmountOut(
        opportunity.estimatedAmountOut,
        effectiveSlippageBpsSell
      );
      const sellParams: SwapParams = {
        tokenIn: opportunity.sellPool.config.token0, // ADRIAN
        tokenOut: opportunity.sellPool.config.token1, // ETH/USDC
        amountIn: adrianReceived,
        amountOutMin: minOut > 0n ? minOut : 1n,
        poolId: opportunity.sellPool.config.id,
        poolType: opportunity.sellPool.config.type,
      };

      logger.info('Ejecutando swap de venta...');
      const sellTx = await this.swapService.executeSwap(sellParams);
      logger.info('Swap de venta enviado', { hash: sellTx.hash });

      // Esperar confirmación
      const sellReceipt = await sellTx.wait();
      if (!sellReceipt) {
        throw new Error('Sell transaction receipt is null');
      }
      logger.info('Swap de venta confirmado', {
        blockNumber: sellReceipt.blockNumber,
        status: sellReceipt.status,
      });

      // Calcular ganancia real como delta neto de ETH (incluye gas)
      const ethAfterAll = await this.provider.getBalance(this.signer.address);
      const realProfit = ethAfterAll - ethBeforeAll;
      const gasUsed = (buyReceipt!.gasUsed || 0n) + (sellReceipt.gasUsed || 0n);
      const gasPrice = await this.gasEstimator.getGasPrice();
      const realGas = gasUsed * gasPrice;

      logger.info('Arbitraje completado', {
        realProfit: ethers.formatEther(realProfit),
        realGas: ethers.formatEther(realGas),
        estimatedProfit: ethers.formatEther(opportunity.estimatedProfit),
      });

      // Registrar éxito (resetea contador de fallos)
      if (this.emergencyMode) {
        await this.emergencyMode.recordSuccess();
      }

      // Verificar si la ganancia real es negativa o muy inferior a la estimada
      const profitDiff = realProfit > opportunity.estimatedProfit
        ? realProfit - opportunity.estimatedProfit
        : opportunity.estimatedProfit - realProfit;
      const profitDiffPercent = opportunity.estimatedProfit > 0n
        ? Number((profitDiff * 10000n) / opportunity.estimatedProfit) / 100
        : 100;

      // Si la ganancia real es negativa o muy inferior (más del 50% de diferencia), registrar como fallo
      if (realProfit <= 0n || profitDiffPercent > 50) {
        const reason: FailureReason = realProfit <= 0n ? 'no_profit' : 'slippage_exceeded';
        const details = realProfit <= 0n
          ? `Ganancia real: ${ethers.formatEther(realProfit)} ETH (esperada: ${ethers.formatEther(opportunity.estimatedProfit)} ETH)`
          : `Diferencia de ganancia: ${profitDiffPercent.toFixed(2)}%`;
        
        if (this.emergencyMode) {
          const emergencyActivated = await this.emergencyMode.recordFailure(
            reason,
            `${buyTx.hash},${sellTx.hash}`,
            details
          );
          
          if (emergencyActivated) {
            logger.error('🚨 MODO DE EMERGENCIA ACTIVADO AUTOMÁTICAMENTE');
          }
        }
      }

      return {
        txHash1: buyTx.hash,
        txHash2: sellTx.hash,
        realProfit,
        realGas,
      };
    } catch (error: any) {
      logger.error('Error ejecutando arbitraje', {
        error: error.message,
        stack: error.stack,
      });

      // Determinar razón del fallo
      let failureReason: FailureReason = 'unknown';
      if (error.message?.includes('revert') || error.message?.includes('reverted')) {
        failureReason = 'transaction_reverted';
      } else if (error.message?.includes('gas') || error.message?.includes('insufficient')) {
        failureReason = 'insufficient_gas';
      } else if (error.message?.includes('slippage')) {
        failureReason = 'slippage_exceeded';
      } else if (error.message?.includes('pool') || error.message?.includes('liquidity')) {
        failureReason = 'pool_error';
      } else if (error.message?.includes('network') || error.message?.includes('timeout')) {
        failureReason = 'network_error';
      }

      // Registrar fallo en modo de emergencia
      if (this.emergencyMode) {
        const emergencyActivated = await this.emergencyMode.recordFailure(
          failureReason,
          undefined,
          error.message
        );
        
        if (emergencyActivated) {
          logger.error('🚨 MODO DE EMERGENCIA ACTIVADO AUTOMÁTICAMENTE');
        }
      }

      throw error;
    }
  }

  /**
   * Verifica que tenemos balances suficientes
   */
  private async verifyBalances(opportunity: ArbitrageOpportunity): Promise<void> {
    const tokenIn = opportunity.buyPool.config.token1; // ETH/USDC
    const requiredAmount = opportunity.estimatedAmountIn;

    if (tokenIn.toLowerCase() === '0x4200000000000000000000000000000000000006') {
      // ETH
      const balance = await this.provider.getBalance(this.signer.address);
      if (balance < requiredAmount) {
        throw new Error(`Balance ETH insuficiente: ${ethers.formatEther(balance)} < ${ethers.formatEther(requiredAmount)}`);
      }
    } else {
      // ERC20 token (USDC, etc.)
      const ERC20ABI = require('../contracts/ERC20.abi.json');
      const token = new ethers.Contract(tokenIn, ERC20ABI, this.provider);
      const balance = await token.balanceOf(this.signer.address);
      if (balance < requiredAmount) {
        throw new Error(`Balance token insuficiente: ${ethers.formatEther(balance)} < ${ethers.formatEther(requiredAmount)}`);
      }
    }
  }

  /**
   * Calcula cantidad mínima de salida considerando slippage
   */
  private calculateMinAmountOut(amountOut: bigint, slippageBps: number): bigint {
    const slippageMultiplier = 10000n - BigInt(Math.floor(slippageBps));
    const result = (amountOut * slippageMultiplier) / 10000n;
    return result > 0n ? result : 0n;
  }

  /**
   * Obtiene cantidad de ADRIAN recibida de un swap
   */
  private async getTokenBalance(tokenAddress: string): Promise<bigint> {
    if (tokenAddress.toLowerCase() === '0x4200000000000000000000000000000000000006') {
      return await this.provider.getBalance(this.signer.address);
    }
    const ERC20ABI = require('../contracts/ERC20.abi.json');
    const token = new ethers.Contract(tokenAddress, ERC20ABI, this.provider);
    return await token.balanceOf(this.signer.address);
  }

  private async getTokenBalanceAt(tokenAddress: string, blockTag: number): Promise<bigint> {
    try {
      if (tokenAddress.toLowerCase() === '0x4200000000000000000000000000000000000006') {
        return await this.provider.getBalance(this.signer.address, blockTag);
      }
      const ERC20ABI = require('../contracts/ERC20.abi.json');
      const token = new ethers.Contract(tokenAddress, ERC20ABI, this.provider);
      return await token.balanceOf(this.signer.address, { blockTag });
    } catch (err: any) {
      logger.warn('Fallo leyendo balance con blockTag, usando balance actual', {
        error: err.message,
        blockTag,
      });
      return await this.getTokenBalance(tokenAddress);
    }
  }

  private getAdrianFromLogs(
    receipt: ethers.ContractTransactionReceipt,
    adrianAddress: string
  ): bigint {
    try {
      const transferTopic = ethers.id('Transfer(address,address,uint256)');
      let total = 0n;
      for (const log of receipt.logs || []) {
        if (log.address.toLowerCase() !== adrianAddress.toLowerCase()) continue;
        if (log.topics[0]?.toLowerCase() !== transferTopic.toLowerCase()) continue;
        const to = '0x' + log.topics[2].slice(26);
        if (to.toLowerCase() !== this.signer.address.toLowerCase()) continue;
        const amount = BigInt(log.data);
        total += amount;
      }
      return total;
    } catch (err: any) {
      logger.warn('No se pudo parsear Transfer logs, fallback a delta', { error: err.message });
      return 0n;
    }
  }

  private getEffectiveSlippageBps(
    opportunity: ArbitrageOpportunity,
    leg: 'buy' | 'sell'
  ): number {
    const base = Math.max(opportunity.estimatedSlippage || 0, 50);
    const pool = leg === 'buy' ? opportunity.buyPool : opportunity.sellPool;
    const liq = pool.data?.liquidity ? Number(pool.data.liquidity) : null;
    const amt = Number(opportunity.estimatedAmountIn);
    if (!liq || liq <= 0 || amt <= 0) return base;
    const utilization = amt / liq;
    if (utilization > 0.1) return base + 1500; // +15%
    if (utilization > 0.05) return base + 500; // +5%
    return base;
  }
}

