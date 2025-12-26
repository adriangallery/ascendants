# 🔧 SOLUCIÓN DEFINITIVA: Railway no encuentra railway.json

## Problema

Railway no está detectando automáticamente el `railway.json` dentro de `adrian-arbitrage-bot/` incluso cuando Root Directory está configurado.

## Solución: Configurar Explícitamente en Railway UI

### Opción 1: Especificar la Ruta del railway.json (RECOMENDADO)

1. **Ve a Railway → Tu Servicio `adrian-arbitrage-bot` → Settings**

2. **Settings → Source:**
   - **Root Directory**: `adrian-arbitrage-bot`
   - **Watch Paths**: `adrian-arbitrage-bot/**`

3. **Settings → Config-as-code:**
   - Haz clic en **"Railway Config File"** o **"Add File Path"**
   - Escribe exactamente: `railway.json`
   - (Cuando Root Directory = `adrian-arbitrage-bot`, Railway busca `railway.json` relativo a ese directorio)
   - Haz clic en **"Save"** o **"Update"**

4. **Settings → Build:**
   - **Build Command**: Deja vacío O especifica: `npm install && npm run build`
   - Railway debería usar el comando del `railway.json` si está configurado correctamente

5. **Settings → Deploy:**
   - **Start Command**: Deja vacío O especifica: `node start.js`
   - Railway debería usar el comando del `railway.json` si está configurado correctamente

### Opción 2: Configurar Comandos Manualmente (Si Opción 1 no funciona)

Si Railway sigue sin usar el `railway.json`, configura los comandos manualmente:

1. **Settings → Source:**
   - **Root Directory**: `adrian-arbitrage-bot`
   - **Watch Paths**: `adrian-arbitrage-bot/**`

2. **Settings → Build → Build Command:**
   - Pega exactamente: `npm install && npm run build`
   - Haz clic en **"Update"**

3. **Settings → Deploy → Start Command:**
   - Pega exactamente: `node start.js`
   - Haz clic en **"Update"**

## Verificación

Después de configurar, haz un **Redeploy** y verifica los logs:

### ✅ Logs CORRECTOS:
```
found 'railway.json' at 'railway.json'
npm install && npm run build
node start.js
🔍 VALIDACIÓN PRE-INICIO
📛 Package name: adrian-arbitrage-bot
🚀 ADRIAN ARBITRAGE BOT - CARGANDO ARCHIVO bot.ts
```

### ❌ Logs INCORRECTOS:
```
Error: Failed to read app source directory
No such file or directory
```

## Notas Importantes

1. **Cuando Root Directory = `adrian-arbitrage-bot`:**
   - Railway ejecuta todos los comandos desde `adrian-arbitrage-bot/`
   - El `railway.json` debe estar en `adrian-arbitrage-bot/railway.json`
   - Los comandos NO necesitan `cd adrian-arbitrage-bot`

2. **Si Railway no detecta el `railway.json`:**
   - Especifica la ruta en Settings → Config-as-code → Railway Config File: `railway.json`
   - O configura los comandos manualmente en Build y Deploy

3. **El `railway.json` actual tiene:**
   ```json
   {
     "build": {
       "buildCommand": "npm install && npm run build"
     },
     "deploy": {
       "startCommand": "node start.js"
     }
   }
   ```

## Troubleshooting

### Railway sigue mostrando "Failed to read app source directory"

1. Verifica que Root Directory = `adrian-arbitrage-bot` (exactamente, sin espacios)
2. Verifica que el `railway.json` existe en `adrian-arbitrage-bot/railway.json` en GitHub
3. Especifica explícitamente la ruta en Settings → Config-as-code → Railway Config File: `railway.json`
4. Si persiste, configura los comandos manualmente (Opción 2)

### Railway ejecuta el NFT bot en lugar del Adrian bot

1. Verifica que estás en el servicio correcto (`adrian-arbitrage-bot`)
2. Verifica que Root Directory = `adrian-arbitrage-bot` (no vacío)
3. Verifica que las variables de entorno son las del bot ADRIAN, no del NFT

