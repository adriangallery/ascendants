# ✅ CONFIGURACIÓN FINAL: adrian-arbitrage-bot en Railway

## Estrategia: Sin Root Directory (como el NFT bot que funciona)

El error "Failed to read app source directory" ocurre cuando Root Directory está configurado. La solución es **NO usar Root Directory** y dejar que los comandos `cd` en el `railway.json` manejen el cambio de directorio.

## Configuración en Railway UI

### Para el servicio `adrian-arbitrage-bot`:

1. **Settings → Source:**
   - **Root Directory**: **VACÍO** (borra cualquier texto, debe estar completamente vacío)
   - **Watch Paths**: `adrian-arbitrage-bot/**`
   - Haz clic en **"Update"**

2. **Settings → Build:**
   - **Build Command**: Deja vacío (Railway usará el del `railway.json`)
   - O especifica manualmente: `cd adrian-arbitrage-bot && npm install && npm run build`

3. **Settings → Deploy:**
   - **Start Command**: Deja vacío (Railway usará el del `railway.json`)
   - O especifica manualmente: `cd adrian-arbitrage-bot && node start.js`

4. **Settings → Config-as-code (OPCIONAL):**
   - **Railway Config File**: `adrian-arbitrage-bot/railway.json`
   - Esto asegura que Railway use el `railway.json` correcto

## railway.json Actual

El `railway.json` en `adrian-arbitrage-bot/railway.json` tiene:

```json
{
  "build": {
    "buildCommand": "cd adrian-arbitrage-bot && npm install && npm run build"
  },
  "deploy": {
    "startCommand": "cd adrian-arbitrage-bot && node start.js"
  }
}
```

## Verificación

Después de configurar:

1. **Haz un Redeploy** desde Railway UI
2. **Verifica los logs** - deben mostrar:
   ```
   found 'railway.json' at 'adrian-arbitrage-bot/railway.json'
   cd adrian-arbitrage-bot && npm install && npm run build
   cd adrian-arbitrage-bot && node start.js
   🔍 VALIDACIÓN PRE-INICIO
   📛 Package name: adrian-arbitrage-bot
   🚀 ADRIAN ARBITRAGE BOT - CARGANDO ARCHIVO bot.ts
   ```

## Comparación con NFT Bot (que funciona)

El NFT bot funciona con:
- **Root Directory**: Probablemente vacío o `nft-arbitrage-bot copyv2`
- **railway.json**: Tiene comandos sin `cd` (porque usa Root Directory) O con `cd` (si Root Directory está vacío)

Para el Adrian bot, usamos la misma estrategia que funciona: **Root Directory vacío + comandos `cd` en railway.json**.

## Troubleshooting

### Error: "Failed to read app source directory"

**Causa**: Root Directory está configurado cuando no debería estarlo.

**Solución**:
1. Ve a Settings → Source → Root Directory
2. **Borra completamente** el contenido (debe estar vacío)
3. Guarda
4. Redeploy

### Railway ejecuta el NFT bot

**Causa**: Railway está leyendo el `package.json` incorrecto.

**Solución**:
1. Verifica que Root Directory está **VACÍO**
2. Verifica que Watch Paths = `adrian-arbitrage-bot/**`
3. Verifica que el `railway.json` tiene los comandos `cd adrian-arbitrage-bot`
4. El script `start.js` validará automáticamente el bot correcto

## Resumen

- ✅ Root Directory: **VACÍO**
- ✅ Watch Paths: `adrian-arbitrage-bot/**`
- ✅ railway.json: Tiene comandos `cd adrian-arbitrage-bot`
- ✅ Build Command: `cd adrian-arbitrage-bot && npm install && npm run build`
- ✅ Start Command: `cd adrian-arbitrage-bot && node start.js`

