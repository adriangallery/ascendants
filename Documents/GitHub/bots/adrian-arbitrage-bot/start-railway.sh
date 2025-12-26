#!/bin/bash
# Script wrapper para Railway que asegura que estamos en el directorio correcto

# Obtener el directorio del script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Cambiar al directorio del script
cd "$SCRIPT_DIR" || exit 1

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ]; then
    echo "❌ ERROR: No se encontró package.json en el directorio actual"
    echo "Directorio actual: $(pwd)"
    exit 1
fi

# Verificar que el package.json es del bot correcto
PACKAGE_NAME=$(node -p "require('./package.json').name")
if [ "$PACKAGE_NAME" != "adrian-arbitrage-bot" ]; then
    echo "❌ ERROR CRÍTICO: Package name incorrecto"
    echo "Esperado: adrian-arbitrage-bot"
    echo "Detectado: $PACKAGE_NAME"
    echo "Directorio actual: $(pwd)"
    exit 1
fi

# Ejecutar el bot
echo "✓ Verificación pasada. Ejecutando bot desde: $(pwd)"
node dist/bot.js

