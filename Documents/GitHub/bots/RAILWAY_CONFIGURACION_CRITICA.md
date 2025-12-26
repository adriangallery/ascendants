# 🚨 CONFIGURACIÓN CRÍTICA PARA RAILWAY - ADRIAN ARBITRAGE BOT

## ⚠️ PROBLEMA ACTUAL

Los logs muestran que Railway está ejecutando el **NFT bot** (`nft-arbitrage-bot@2.0.0 start:prod`) en lugar del **adrian-arbitrage-bot**. Esto ocurre porque el "Start Command" en Railway UI está configurado incorrectamente.

## ✅ SOLUCIÓN DEFINITIVA

### Configuración EXACTA en Railway UI para el servicio `adrian-arbitrage-bot`:

1. **Settings → Source:**
   - **Root Directory**: **VACÍO** (borra completamente cualquier texto)
   - **Watch Paths**: `adrian-arbitrage-bot/**` (sin barra inicial)

2. **Settings → Build:**
   - **Build Command**: `cd adrian-arbitrage-bot && npm install && npm run build`
   - (Si está vacío, cópialo y pégalo exactamente así)

3. **Settings → Deploy:**
   - **Start Command**: `node start-adrian-bot.js`
   - ⚠️ **CRÍTICO**: NO uses `npm run start:prod` - ese comando ejecuta el bot incorrecto
   - ⚠️ **CRÍTICO**: NO uses `cd adrian-arbitrage-bot && node start.js` - usa el wrapper de la raíz
   - (Si está vacío o tiene otro comando, cámbialo exactamente a: `node start-adrian-bot.js`)

4. **Settings → Variables:**
   - Asegúrate de tener todas las variables de entorno necesarias para el `adrian-arbitrage-bot`
   - NO necesitas variables del NFT bot (`NFT_COLLECTION_ADDRESS`, `FLOOR_ENGINE_ADDRESS`)

## 🔍 Verificación en los Logs

Después de aplicar estos cambios y hacer un **Redeploy**, los logs deben mostrar:

### ✅ Logs CORRECTOS (Adrian bot):
```
========================================
🚀 ADRIAN ARBITRAGE BOT - WRAPPER
========================================
📁 Directorio actual (wrapper): /app
✅ Bot correcto detectado: adrian-arbitrage-bot
========================================
🔍 VALIDACIÓN PRE-INICIO
========================================
📛 Package name: adrian-arbitrage-bot
✅ Validación pasada
🚀 ADRIAN ARBITRAGE BOT - CARGANDO ARCHIVO bot.ts
```

### ❌ Logs INCORRECTOS (NFT bot - si ves esto, la configuración está mal):
```
> nft-arbitrage-bot@2.0.0 start:prod
=== NFT ARBITRAGE BOT v2.0.0 - INICIANDO ===
Missing required environment variables: NFT_COLLECTION_ADDRESS, FLOOR_ENGINE_ADDRESS
```

## 🛠️ Cómo Verificar la Configuración Actual

1. Ve a tu servicio `adrian-arbitrage-bot` en Railway
2. Haz clic en **Settings**
3. Verifica cada sección:
   - **Source → Root Directory**: Debe estar VACÍO
   - **Build → Build Command**: Debe ser `cd adrian-arbitrage-bot && npm install && npm run build`
   - **Deploy → Start Command**: Debe ser `node start-adrian-bot.js` (NO `npm run start:prod`)
   - **Build → Watch Paths**: Debe tener `adrian-arbitrage-bot/**`

## 📝 Notas Importantes

- El wrapper `start-adrian-bot.js` está en la **raíz del repositorio**
- Este wrapper valida que se esté ejecutando el bot correcto antes de iniciarlo
- Si Railway está ejecutando desde el directorio incorrecto, el wrapper fallará inmediatamente con un mensaje de error claro
- El `railway.json` dentro de `adrian-arbitrage-bot/` puede no ser detectado si Railway UI tiene comandos manuales configurados

## 🔄 Si Sigue Fallando

1. **Borra completamente** el "Start Command" en Railway UI
2. **Guarda** los cambios
3. **Vuelve a añadir** exactamente: `node start-adrian-bot.js`
4. **Guarda** de nuevo
5. **Haz un Redeploy manual** desde Railway UI

Si después de esto sigues viendo logs del NFT bot, puede ser un problema de caché en Railway. Intenta:
- Eliminar y recrear el servicio
- O contactar con el soporte de Railway

