import { ethers } from 'ethers';

// Configuración del proveedor
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const contractAddress = process.env.CONTRACT_ADDRESS;

// ABI mínimo necesario
const MIN_ABI = [
    "function getTokenTraits(uint256 tokenId) external view returns (mapping(string => uint256) memory)",
    "function generation(uint256 tokenId) external view returns (uint256)",
    "function mutationLevel(uint256 tokenId) external view returns (string memory)"
];

// Instancia del contrato
const contract = new ethers.Contract(contractAddress, MIN_ABI, provider);

// Función para obtener traits de un token
export async function getTokenTraits(tokenId) {
    try {
        // Obtener generación y nivel de mutación
        const [generation, mutationLevel] = await Promise.all([
            contract.generation(tokenId),
            contract.mutationLevel(tokenId)
        ]);

        // Obtener traits
        const traits = await contract.getTokenTraits(tokenId);

        // Convertir mapping a objeto
        const traitData = {
            generation,
            mutationLevel,
            base: traits['BASE'] || 0,
            body: traits['BODY'] || 0,
            clothing: traits['CLOTHING'] || 0,
            eyes: traits['EYES'] || 0,
            mouth: traits['MOUTH'] || 0,
            head: traits['HEAD'] || 0,
            accessories: traits['ACCESSORIES'] || 0
        };

        return traitData;
    } catch (error) {
        console.error('Error getting token traits:', error);
        throw error;
    }
}

// Función para verificar si un token existe
export async function tokenExists(tokenId) {
    try {
        await contract.generation(tokenId);
        return true;
    } catch (error) {
        return false;
    }
}

// Función para obtener metadatos de un token
export async function getTokenMetadata(tokenId) {
    try {
        const traitData = await getTokenTraits(tokenId);
        
        return {
            name: `BareAdrian #${tokenId}`,
            description: "A unique BareAdrian from the AdrianLab collection",
            image: `${process.env.RENDER_BASE_URL}/api/render/${tokenId}`,
            attributes: [
                {
                    trait_type: "Generation",
                    value: traitData.generation.toString()
                },
                {
                    trait_type: "Mutation Level",
                    value: traitData.mutationLevel
                },
                {
                    trait_type: "Base",
                    value: traitData.base.toString()
                },
                {
                    trait_type: "Body",
                    value: traitData.body.toString()
                },
                {
                    trait_type: "Clothing",
                    value: traitData.clothing.toString()
                },
                {
                    trait_type: "Eyes",
                    value: traitData.eyes.toString()
                },
                {
                    trait_type: "Mouth",
                    value: traitData.mouth.toString()
                },
                {
                    trait_type: "Head",
                    value: traitData.head.toString()
                },
                {
                    trait_type: "Accessories",
                    value: traitData.accessories.toString()
                }
            ]
        };
    } catch (error) {
        console.error('Error getting token metadata:', error);
        throw error;
    }
} 