# ⚠️ CONFIGURACIÓN MANUAL REQUERIDA EN RAILWAY UI

## Problema Detectado

Los logs muestran que Railway está ejecutando el **NFT bot** en lugar del **adrian-arbitrage-bot**. Esto ocurre porque los **comandos manuales en Railway UI SOBRESCRIBEN** el archivo `railway.json`.

## Solución: Configurar Manualmente en Railway UI

### Para el servicio `adrian-arbitrage-bot`:

1. **Settings → Source**
   - **Root Directory**: `adrian-arbitrage-bot` (NO vacío)
   - **Watch Paths**: `adrian-arbitrage-bot/**`

2. **Settings → Build**
   - **Build Command**: `npm install && npm run build`
   - (Railway ejecutará esto desde `adrian-arbitrage-bot/` porque Root Directory está configurado)

3. **Settings → Deploy**
   - **Start Command**: `node start.js`
   - (Railway ejecutará esto desde `adrian-arbitrage-bot/` porque Root Directory está configurado)

### Verificación

Después de configurar, los logs deben mostrar:
- `🔍 VALIDACIÓN PRE-INICIO` (de `start.js`)
- `📛 Package name: adrian-arbitrage-bot`
- `🚀 ADRIAN ARBITRAGE BOT - CARGANDO ARCHIVO bot.ts`

Si ves `{"service":"nft-arbitrage-bot"}` o `=== NFT ARBITRAGE BOT`, significa que Railway está ejecutando el código incorrecto.

## Nota sobre railway.json

El archivo `railway.json` **NO se usa** cuando tienes comandos personalizados en Railway UI. Railway prioriza la configuración manual del UI sobre los archivos de configuración.

## Estado Actual

- ✅ `start.js` está configurado para validar el bot correcto
- ✅ `bot.ts` tiene verificación inmediata
- ❌ Railway UI tiene comandos incorrectos que sobrescriben `railway.json`
- ❌ Root Directory puede estar vacío cuando debería ser `adrian-arbitrage-bot`

## Acción Requerida

**Configura manualmente en Railway UI los comandos de Build y Deploy como se indica arriba, y establece Root Directory a `adrian-arbitrage-bot`.**

