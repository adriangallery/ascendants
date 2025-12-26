# Guía Paso a Paso: Crear Nuevo Servicio en Railway

## Crear un Nuevo Servicio para adrian-arbitrage-bot

### Paso 1: Crear el Nuevo Servicio

1. **Ve a tu proyecto en Railway** (el que ya tiene el bot NFT funcionando)
2. **Haz clic en "New"** (botón en la parte superior o en el menú lateral)
3. **Selecciona "GitHub Repo"** o "Empty Service"
4. Si seleccionas "GitHub Repo":
   - Selecciona el mismo repositorio que usas para el bot NFT
   - Railway creará un nuevo servicio conectado al mismo repo

### Paso 2: Configurar el Servicio

Una vez creado el nuevo servicio:

1. **Renombra el servicio** (opcional pero recomendado):
   - Haz clic en el nombre del servicio (arriba a la izquierda)
   - Cámbialo a algo como: `adrian-arbitrage-bot`

2. **Configura el Source (Settings → Source)**:
   - **Root Directory**: `adrian-arbitrage-bot`
   - Esto le dice a Railway que este servicio solo debe trabajar con archivos en ese directorio

3. **Configura Watch Paths (Settings → Build → Watch Paths)**:
   - Añade: `adrian-arbitrage-bot/**`
   - Esto hace que Railway solo despliegue cuando cambien archivos en ese directorio
   - **Importante**: Si usas Root Directory, los Watch Paths son opcionales pero recomendados

4. **Verifica Build Command (Settings → Build)**:
   - Railway debería detectar automáticamente el `railway.json` en `adrian-arbitrage-bot/`
   - Si no lo detecta, configura manualmente:
     - **Build Command**: `npm install && npm run build`
   - **Nota**: Si usas Root Directory, NO necesitas `cd` porque Railway ya está en ese directorio

5. **Verifica Start Command (Settings → Deploy)**:
   - Railway debería detectar automáticamente el `railway.json`
   - Si no lo detecta, configura manualmente:
     - **Start Command**: `npm run start:prod`

### Paso 3: Configurar Variables de Entorno

1. **Ve a Settings → Variables**
2. **Añade todas las variables necesarias** para el bot de arbitraje:
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

### Paso 4: Activar el Deploy

1. Railway debería detectar automáticamente el cambio y empezar a construir
2. Si no se activa automáticamente:
   - Ve a la pestaña "Deployments"
   - Haz clic en "Redeploy" o "Deploy Latest"

## Configuración del Servicio NFT (Verificar)

Para asegurarte de que el servicio NFT solo se despliega cuando cambian sus archivos:

1. **Ve al servicio del bot NFT**
2. **Settings → Source**:
   - **Root Directory**: `nft-arbitrage-bot copyv2`
3. **Settings → Build → Watch Paths**:
   - Añade: `nft-arbitrage-bot copyv2/**`

## Resumen de Configuración

### Servicio 1: NFT Bot
- **Nombre**: `nft-arbitrage-bot` (o como lo tengas)
- **Root Directory**: `nft-arbitrage-bot copyv2`
- **Watch Paths**: `nft-arbitrage-bot copyv2/**`
- **Variables**: Las del bot NFT

### Servicio 2: Adrian Arbitrage Bot
- **Nombre**: `adrian-arbitrage-bot`
- **Root Directory**: `adrian-arbitrage-bot`
- **Watch Paths**: `adrian-arbitrage-bot/**`
- **Variables**: Las del bot de arbitraje ADRIAN

## Notas Importantes

- Cada servicio es **independiente**: cambios en uno no afectan al otro
- Cada servicio tiene sus **propias variables de entorno**
- Cada servicio se despliega **solo cuando cambian archivos en su directorio** (gracias a Watch Paths)
- El `railway.json` en cada directorio se detecta automáticamente cuando usas Root Directory

