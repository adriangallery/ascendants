import { createCanvas, loadImage } from 'canvas';
import { ethers } from 'ethers';
import { getTokenTraits } from '../../../lib/blockchain';
import { getImageForTrait } from '../../../lib/imageProcessor';
import { cacheResult, getCachedResult } from '../../../lib/cache';

// ABI mínimo necesario para obtener traits
const MIN_ABI = [
  "function getTokenTraits(uint256 tokenId) external view returns (mapping(string => uint256) memory)",
  "function generation(uint256 tokenId) external view returns (uint256)",
  "function mutationLevel(uint256 tokenId) external view returns (string memory)"
];

export default async function handler(req, res) {
    const { tokenId } = req.query;
    
    // Verificar caché
    const cachedImage = await getCachedResult(tokenId);
    if (cachedImage) {
        res.setHeader('Content-Type', 'image/png');
        res.setHeader('Cache-Control', 'public, max-age=3600, s-maxage=86400');
        return res.send(cachedImage);
    }
    
    try {
        // Obtener datos del token desde la blockchain
        const traitData = await getTokenTraits(tokenId);
        
        // Crear canvas
        const canvas = createCanvas(1000, 1000);
        const ctx = canvas.getContext('2d');
        
        // Cargar y dibujar capa base
        const baseImage = await loadImage(await getImageForTrait('BASE', traitData.base));
        ctx.drawImage(baseImage, 0, 0, 1000, 1000);
        
        // Dibujar traits adicionales en orden
        const traitOrder = ['BODY', 'CLOTHING', 'EYES', 'MOUTH', 'HEAD', 'ACCESSORIES'];
        for (const category of traitOrder) {
            if (traitData[category]) {
                // Lógica condicional para traits
                if (category === 'HAIR' && traitData['HAT'] > 0) {
                    // Si tiene sombrero, usar versión alternativa del pelo
                    const traitImage = await loadImage(await getImageForTrait(category, `${traitData[category]}_alt`));
                    ctx.drawImage(traitImage, 0, 0, 1000, 1000);
                } else {
                    const traitImage = await loadImage(await getImageForTrait(category, traitData[category]));
                    ctx.drawImage(traitImage, 0, 0, 1000, 1000);
                }
            }
        }
        
        // Aplicar efectos de mutación si existen
        if (traitData.mutationLevel !== 'None') {
            const mutationOverlay = await loadImage(`./public/MUTATION/${traitData.mutationLevel.toLowerCase()}.png`);
            ctx.drawImage(mutationOverlay, 0, 0, 1000, 1000);
        }
        
        // Convertir a buffer y devolver
        const buffer = canvas.toBuffer('image/png');
        res.setHeader('Content-Type', 'image/png');
        res.setHeader('Cache-Control', 'public, max-age=3600, s-maxage=86400');
        
        // Guardar en caché
        await cacheResult(tokenId, buffer);
        
        res.send(buffer);
    } catch (error) {
        console.error('Error rendering image:', error);
        res.status(500).json({ error: 'Failed to render image' });
    }
} 