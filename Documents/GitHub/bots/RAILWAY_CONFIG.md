# Configuración Railway - Bots Multi-Servicio

Este documento describe la configuración de Railway para desplegar múltiples bots de forma independiente desde un solo repositorio.

## Estructura del Repositorio

```
bots/
├── adrian-arbitrage-bot/          # Bot de arbitraje ADRIAN
├── nft-arbitrage-bot copyv2/      # Bot de arbitraje NFT
└── [futuros bots...]
```

## Configuración por Servicio

Cada bot debe tener su propio servicio en Railway con la siguiente configuración:

### 1. adrian-arbitrage-bot

**Settings → Source:**
- Root Directory: `adrian-arbitrage-bot` (o dejar vacío si usas Watch Paths)

**Settings → Build:**
- Watch Paths: `adrian-arbitrage-bot/**`
- Build Command: `cd adrian-arbitrage-bot && npm install && npm run build`

**Settings → Deploy:**
- Start Command: `cd adrian-arbitrage-bot && npm run start:prod`

### 2. nft-arbitrage-bot copyv2

**Settings → Source:**
- Root Directory: `nft-arbitrage-bot copyv2` (o dejar vacío si usas Watch Paths)

**Settings → Build:**
- Watch Paths: `nft-arbitrage-bot copyv2/**`
- Build Command: `cd "nft-arbitrage-bot copyv2" && npm install && npm run build`

**Settings → Deploy:**
- Start Command: `cd "nft-arbitrage-bot copyv2" && npm run start:prod`

## Recomendación: Usar Watch Paths (sin Root Directory)

**Ventajas:**
- Cada servicio solo se despliega cuando cambian archivos en su directorio
- No necesitas configurar Root Directory
- Más fácil de mantener
- Menos propenso a errores

**Configuración:**
1. **NO configures Root Directory** (déjalo vacío o elimínalo)
2. **SÍ configura Watch Paths** en Build → Watch Paths:
   - Para adrian-arbitrage-bot: `adrian-arbitrage-bot/**`
   - Para nft-arbitrage-bot: `nft-arbitrage-bot copyv2/**`

## Añadir Nuevos Bots

Para añadir un nuevo bot:

1. Crea el directorio del bot en el repositorio
2. Crea un `railway.json` en el directorio del bot (copia de uno existente y ajusta)
3. Crea un nuevo servicio en Railway
4. Configura Watch Paths: `[nombre-del-bot]/**`
5. Configura Build Command: `cd [nombre-del-bot] && npm install && npm run build`
6. Configura Start Command: `cd [nombre-del-bot] && npm run start:prod`
7. Añade las variables de entorno necesarias

## Variables de Entorno

Cada servicio tiene sus propias variables de entorno. Configúralas en Railway → Settings → Variables.

### adrian-arbitrage-bot
- `PRIVATE_KEY`
- `RPC_URL`
- `ADRIAN_TOKEN_ADDRESS`
- `WETH_ADDRESS`
- `USDC_ADDRESS`
- `UNISWAP_V2_ROUTER`
- `UNISWAP_V3_ROUTER`
- `UNISWAP_V4_POOL_MANAGER`
- `UNISWAP_V4_POOL_ADDRESS`
- `ADRIAN_SWAPPER_ADDRESS`
- `EXECUTION_MODE=production`
- `MIN_PROFIT_MARGIN_BPS`
- `EXECUTION_INTERVAL_SECONDS`
- (Ver `adrian-arbitrage-bot/ENV_SETUP.md` para lista completa)

### nft-arbitrage-bot copyv2
- `PRIVATE_KEY`
- `RPC_URL`
- `NFT_COLLECTION_ADDRESS`
- `FLOOR_ENGINE_ADDRESS`
- `ADRIAN_TOKEN_ADDRESS`
- `OPENSEA_API_KEY`
- (Ver `nft-arbitrage-bot copyv2/README.md` para lista completa)

