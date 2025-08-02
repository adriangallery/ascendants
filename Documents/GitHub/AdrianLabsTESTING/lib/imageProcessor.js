import { promises as fs } from 'fs';
import path from 'path';

// Directorio base para los assets
const ASSETS_DIR = path.join(process.cwd(), 'public', 'traits');

// Función para obtener la ruta de la imagen de un trait
export async function getImageForTrait(category, traitId) {
    try {
        // Construir ruta del archivo
        const filePath = path.join(ASSETS_DIR, category, `${traitId}.png`);
        
        // Verificar si el archivo existe
        try {
            await fs.access(filePath);
        } catch (error) {
            // Si no existe, intentar con la versión por defecto
            const defaultPath = path.join(ASSETS_DIR, category, 'default.png');
            try {
                await fs.access(defaultPath);
                return defaultPath;
            } catch (error) {
                throw new Error(`No image found for trait ${category}/${traitId}`);
            }
        }
        
        return filePath;
    } catch (error) {
        console.error('Error getting trait image:', error);
        throw error;
    }
}

// Función para verificar si un trait tiene una versión alternativa
export async function hasAlternativeVersion(category, traitId) {
    try {
        const altPath = path.join(ASSETS_DIR, category, `${traitId}_alt.png`);
        await fs.access(altPath);
        return true;
    } catch (error) {
        return false;
    }
}

// Función para obtener la lista de traits disponibles por categoría
export async function getAvailableTraits(category) {
    try {
        const categoryDir = path.join(ASSETS_DIR, category);
        const files = await fs.readdir(categoryDir);
        
        return files
            .filter(file => file.endsWith('.png') && !file.includes('_alt'))
            .map(file => parseInt(file.replace('.png', '')));
    } catch (error) {
        console.error('Error getting available traits:', error);
        return [];
    }
}

// Función para verificar si un trait es compatible con otro
export async function areTraitsCompatible(trait1, trait2) {
    // Aquí puedes implementar lógica de compatibilidad
    // Por ejemplo, algunos sombreros pueden no ser compatibles con ciertos peinados
    return true;
}

// Función para obtener el orden de renderizado de los traits
export function getTraitRenderOrder() {
    return [
        'BASE',
        'BODY',
        'CLOTHING',
        'EYES',
        'MOUTH',
        'HEAD',
        'ACCESSORIES'
    ];
}

// Función para obtener la configuración de capas de un trait
export async function getTraitLayerConfig(category, traitId) {
    try {
        const configPath = path.join(ASSETS_DIR, category, `${traitId}.json`);
        const configData = await fs.readFile(configPath, 'utf8');
        return JSON.parse(configData);
    } catch (error) {
        // Si no hay configuración específica, devolver valores por defecto
        return {
            zIndex: 0,
            blendMode: 'normal',
            opacity: 1
        };
    }
} 