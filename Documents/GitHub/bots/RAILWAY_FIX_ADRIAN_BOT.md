# 🔧 SOLUCIÓN: Railway ejecutando NFT bot en lugar de Adrian bot

## Problema

Railway está ejecutando el código del `nft-arbitrage-bot` en lugar del `adrian-arbitrage-bot`. Los logs muestran:
- `"> nft-arbitrage-bot@2.0.0 start:prod"`
- `"=== NFT ARBITRAGE BOT v2.0.0 - INICIANDO ==="`
- `{"service":"nft-arbitrage-bot"}`

## Solución: Configurar Manualmente los Comandos en Railway

Railway NO está usando el `railway.json` automáticamente. Necesitas configurar los comandos manualmente en la UI de Railway.

### Pasos Exactos:

1. **Ve al servicio `adrian-arbitrage-bot` en Railway**

2. **Settings → Source**:
   - **Root Directory**: Debe estar **COMPLETAMENTE VACÍO** (borra cualquier texto que haya)

3. **Settings → Build → Build Command**:
   - **Borra** el comando actual si existe
   - **Pega exactamente esto**:
     ```
     cd adrian-arbitrage-bot && npm install && npm run build
     ```
   - Haz clic en **"Update"**

4. **Settings → Build → Watch Paths**:
   - Debe tener: `adrian-arbitrage-bot/**`
   - Si no está, añádelo

5. **Settings → Deploy → Start Command**:
   - **Borra** el comando actual si existe
   - **Pega exactamente esto**:
     ```
     cd adrian-arbitrage-bot && npm run start:prod
     ```
   - Haz clic en **"Update"**

6. **Settings → Config-as-code → Railway Config File** (OPCIONAL pero recomendado):
   - Haz clic en **"Add File Path"**
   - Escribe: `adrian-arbitrage-bot/railway.json`
   - Esto hará que Railway use el `railway.json` automáticamente

7. **Redeploy**:
   - Ve a la pestaña **"Deployments"**
   - Haz clic en **"Redeploy"** o **"Deploy Latest"**

## Verificación

Después de hacer los cambios, los logs deben mostrar:

```
========================================
🚀 ADRIAN ARBITRAGE BOT - INICIANDO
========================================
✓ Verificación de bot correcto: PASADA
```

Y **NO** deben mostrar:
- `"nft-arbitrage-bot"`
- `"NFT ARBITRAGE BOT"`
- `NFT_COLLECTION_ADDRESS` o `FLOOR_ENGINE_ADDRESS` en los errores

## Si Sigue Fallando

1. **Verifica que el servicio se llama `adrian-arbitrage-bot`** (no `nft-arbitrage-bot` ni `bots`)

2. **Borra completamente los comandos** en Build y Start, guarda, y vuelve a pegarlos

3. **Verifica que el `railway.json` existe** en `adrian-arbitrage-bot/railway.json` en GitHub

4. **Haz un commit pequeño** (añade un comentario) para forzar un nuevo deploy

