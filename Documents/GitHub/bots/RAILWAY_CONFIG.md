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
- Root Directory: `adrian-arbitrage-bot`

**Settings → Build:**
- Build Command: (se toma del `railway.json`, no necesita configuración manual)
- O manualmente: `npm install && npm run build`

**Settings → Deploy:**
- Start Command: (se toma del `railway.json`, no necesita configuración manual)
- O manualmente: `npm run start:prod`

**Nota:** Cuando usas "Root Directory", Railway ejecuta los comandos desde ese directorio, por lo que NO necesitas `cd` en los comandos.

### 2. nft-arbitrage-bot copyv2

**Settings → Source:**
- Root Directory: `nft-arbitrage-bot copyv2`

**Settings → Build:**
- Build Command: (se toma del `railway.json`, no necesita configuración manual)
- O manualmente: `npm install && npm run build`

**Settings → Deploy:**
- Start Command: (se toma del `railway.json`, no necesita configuración manual)
- O manualmente: `npm run start:prod`

**Nota:** Cuando usas "Root Directory", Railway ejecuta los comandos desde ese directorio, por lo que NO necesitas `cd` en los comandos.

## Método Recomendado: Root Directory

**Ventajas:**
- Cada servicio tiene su propio contexto de ejecución
- El `railway.json` dentro de cada directorio se usa automáticamente
- Más simple y directo
- Menos propenso a errores de rutas

**Configuración:**
1. **Configura Root Directory** en Settings → Source para cada servicio
2. El `railway.json` dentro de cada directorio se detecta automáticamente
3. Los comandos en `railway.json` NO necesitan `cd` porque Railway ya está en el directorio correcto

## Alternativa: Watch Paths (sin Root Directory)

Si prefieres NO usar Root Directory:

**Configuración:**
1. **NO configures Root Directory** (déjalo vacío)
2. **SÍ configura Watch Paths** en Build → Watch Paths:
   - Para adrian-arbitrage-bot: `adrian-arbitrage-bot/**`
   - Para nft-arbitrage-bot: `nft-arbitrage-bot copyv2/**`
3. **Configura Build Command manualmente** en Settings → Build:
   - `cd adrian-arbitrage-bot && npm install && npm run build`
   - `cd "nft-arbitrage-bot copyv2" && npm install && npm run build`
4. **Configura Start Command manualmente** en Settings → Deploy:
   - `cd adrian-arbitrage-bot && npm run start:prod`
   - `cd "nft-arbitrage-bot copyv2" && npm run start:prod`

## Añadir Nuevos Bots

Para añadir un nuevo bot:

1. Crea el directorio del bot en el repositorio
2. Crea un `railway.json` en el directorio del bot con:
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm install && npm run build"
  },
  "deploy": {
    "startCommand": "npm run start:prod",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```
3. Crea un nuevo servicio en Railway
4. Configura Root Directory: `[nombre-del-bot]`
5. Añade las variables de entorno necesarias

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

