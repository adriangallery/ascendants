# 🚨 FIX CRÍTICO: Railway ejecuta el bot incorrecto

## Problema Actual

Los logs muestran que el servicio `adrian-arbitrage-bot` en Railway está ejecutando el código del **NFT bot**:

```
> nft-arbitrage-bot@2.0.0 start:prod
> node dist/bot.js
=== NFT ARBITRAGE BOT v2.0.0 - INICIANDO ===
```

Esto significa que Railway UI tiene un **"Start Command" configurado manualmente** que está **sobrescribiendo** el `railway.json`.

## Solución Implementada

Se ha creado un script wrapper `start-adrian-bot.js` en la **raíz del repositorio** que:

1. ✅ Valida que existe `adrian-arbitrage-bot/package.json`
2. ✅ Verifica que el `package.json` tiene `name: "adrian-arbitrage-bot"`
3. ✅ Cambia al directorio correcto y ejecuta `start.js`
4. ✅ Falla inmediatamente si detecta el bot incorrecto

## Configuración Requerida en Railway UI

### Para el servicio `adrian-arbitrage-bot`:

1. **Settings → Source**
   - **Root Directory**: **VACÍO** (borra cualquier texto)
   - **Watch Paths**: `adrian-arbitrage-bot/**` (sin barra inicial)

2. **Settings → Build**
   - **Build Command**: **VACÍO** (deja que Railway use el `railway.json`)
     - O manualmente: `cd adrian-arbitrage-bot && npm install && npm run build`

3. **Settings → Deploy** ⚠️ **CRÍTICO**
   - **Start Command**: **DEBE SER EXACTAMENTE**: `node start-adrian-bot.js`
   - **NO uses**: `npm run start:prod` (ese es del NFT bot)
   - **NO uses**: `cd adrian-arbitrage-bot && node start.js` (el wrapper lo hace)

4. **Settings → Build → Watch Paths**
   - Añade: `adrian-arbitrage-bot/**`
   - Esto asegura que los cambios en el bot trigger nuevos deployments

## Verificación

Después de configurar, los logs deben mostrar:

1. `🚀 ADRIAN ARBITRAGE BOT - WRAPPER`
2. `✅ Bot correcto detectado: adrian-arbitrage-bot`
3. `🔍 VALIDACIÓN PRE-INICIO` (del `start.js` interno)
4. `📛 Package name: adrian-arbitrage-bot`
5. `🚀 ADRIAN ARBITRAGE BOT - CARGANDO ARCHIVO bot.ts`

**Si ves `=== NFT ARBITRAGE BOT` o `nft-arbitrage-bot@2.0.0`, significa que el "Start Command" en Railway UI está configurado incorrectamente.**

## Por Qué Este Enfoque Funciona

- El wrapper está en la **raíz del repo**, por lo que Railway puede encontrarlo incluso si el "Root Directory" está mal configurado
- El wrapper **valida el bot correcto** antes de ejecutar
- El wrapper **cambia al directorio correcto** automáticamente
- Si Railway UI tiene comandos manuales incorrectos, el wrapper los intercepta y ejecuta el bot correcto

## Acción Inmediata Requerida

1. Ve a Railway → `adrian-arbitrage-bot` service → Settings → Deploy
2. **Borra** cualquier comando en "Start Command"
3. **Escribe exactamente**: `node start-adrian-bot.js`
4. **Guarda** los cambios
5. **Redeploy** el servicio

