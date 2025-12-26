# 🔍 Guía de Verificación: Railway Service Configuration

## Problema Actual

Los logs del servicio `adrian-arbitrage-bot` muestran `"service":"nft-arbitrage-bot"`, lo que indica que Railway está ejecutando el código del NFT bot en lugar del bot de arbitraje ADRIAN.

## Pasos de Verificación

### 1. Verificar que tienes DOS servicios separados

1. Ve a tu proyecto en Railway
2. Debes ver **DOS servicios** en la lista:
   - `nft-arbitrage-bot` (o nombre similar)
   - `adrian-arbitrage-bot` (o nombre similar)

**Si solo ves UN servicio**, necesitas crear el segundo servicio siguiendo `RAILWAY_SETUP_GUIDE.md`.

### 2. Verificar el Servicio `adrian-arbitrage-bot`

1. **Haz clic en el servicio `adrian-arbitrage-bot`**
2. **Ve a Settings → Source**:
   - ✅ **Root Directory**: Debe estar **VACÍO** (no debe tener `adrian-arbitrage-bot` ni nada)
   - Si tiene algo, **bórralo completamente**

3. **Ve a Settings → Build → Watch Paths**:
   - ✅ Debe tener: `adrian-arbitrage-bot/**`
   - Si no está, **añádelo**

4. **Ve a Settings → Build → Build Command**:
   - ✅ Debe ser: `cd adrian-arbitrage-bot && npm install && npm run build`
   - O Railway debería detectar automáticamente el `railway.json` en `adrian-arbitrage-bot/`
   - Si no coincide, **cámbialo manualmente**

5. **Ve a Settings → Deploy → Start Command**:
   - ✅ Debe ser: `cd adrian-arbitrage-bot && npm run start:prod`
   - O Railway debería detectar automáticamente el `railway.json` en `adrian-arbitrage-bot/`
   - Si no coincide, **cámbialo manualmente**

6. **Ve a Settings → Variables**:
   - ✅ Debe tener las variables del bot ADRIAN (NO las del NFT bot)
   - Variables clave: `ADRIAN_TOKEN_ADDRESS`, `WETH_ADDRESS`, `UNISWAP_V2_ROUTER`, etc.
   - **NO debe tener**: `NFT_COLLECTION_ADDRESS`, `FLOOR_ENGINE_ADDRESS`

### 3. Verificar el Servicio `nft-arbitrage-bot`

1. **Haz clic en el servicio `nft-arbitrage-bot`**
2. **Ve a Settings → Source**:
   - ✅ **Root Directory**: Debe ser `nft-arbitrage-bot copyv2` (o el nombre de tu directorio NFT)
   - O debe estar **VACÍO** si usas `cd` en el `railway.json`

3. **Ve a Settings → Build → Watch Paths**:
   - ✅ Debe tener: `nft-arbitrage-bot copyv2/**`
   - Si no está, **añádelo**

4. **Ve a Settings → Variables**:
   - ✅ Debe tener las variables del bot NFT
   - Variables clave: `NFT_COLLECTION_ADDRESS`, `FLOOR_ENGINE_ADDRESS`, etc.
   - **NO debe tener**: `ADRIAN_TOKEN_ADDRESS`, `UNISWAP_V4_POOL_ADDRESS` (a menos que ambos bots las necesiten)

### 4. Verificar los Logs

Después de hacer los cambios:

1. **Ve al servicio `adrian-arbitrage-bot`**
2. **Ve a la pestaña "Deployments"**
3. **Haz clic en "Redeploy"** o "Deploy Latest"
4. **Espera a que termine el build**
5. **Ve a la pestaña "Logs"**
6. **Busca estas líneas al inicio**:
   ```
   ========================================
   🚀 ADRIAN ARBITRAGE BOT - INICIANDO
   ========================================
   ```
   Y también:
   ```
   {"service":"adrian-arbitrage-bot"}
   ```

**Si ves `"service":"nft-arbitrage-bot"`**, significa que Railway todavía está ejecutando el código incorrecto. Revisa los pasos 2.3, 2.4 y 2.5.

### 5. Solución de Problemas

#### Problema: Los logs siguen mostrando el NFT bot

**Solución**:
1. Ve a Settings → Build → Build Command
2. **Borra completamente** el comando
3. **Guarda**
4. **Vuelve a Settings → Build → Build Command**
5. **Pega**: `cd adrian-arbitrage-bot && npm install && npm run build`
6. **Guarda**
7. Repite para Start Command con: `cd adrian-arbitrage-bot && npm run start:prod`
8. **Redeploy**

#### Problema: Railway no detecta cambios

**Solución**:
1. Verifica que el `railway.json` en `adrian-arbitrage-bot/` existe y tiene el contenido correcto
2. Verifica que el archivo está en GitHub (no solo local)
3. Haz un commit pequeño (añade un comentario) y push
4. Railway debería detectar el cambio automáticamente

#### Problema: "Failed to read app source directory"

**Solución**:
1. Ve a Settings → Source → Root Directory
2. **Borra completamente** el contenido (debe estar vacío)
3. Guarda
4. Verifica que el Build Command tiene `cd adrian-arbitrage-bot`
5. Redeploy

## Resumen de Configuración Correcta

### Servicio: `adrian-arbitrage-bot`
- **Root Directory**: Vacío
- **Watch Paths**: `adrian-arbitrage-bot/**`
- **Build Command**: `cd adrian-arbitrage-bot && npm install && npm run build`
- **Start Command**: `cd adrian-arbitrage-bot && npm run start:prod`
- **Variables**: Solo las del bot ADRIAN

### Servicio: `nft-arbitrage-bot`
- **Root Directory**: `nft-arbitrage-bot copyv2` (o vacío si el `railway.json` tiene `cd`)
- **Watch Paths**: `nft-arbitrage-bot copyv2/**`
- **Build Command**: Detectado automáticamente o `cd "nft-arbitrage-bot copyv2" && npm install && npm run build`
- **Start Command**: Detectado automáticamente o `cd "nft-arbitrage-bot copyv2" && npm run start:prod`
- **Variables**: Solo las del bot NFT

