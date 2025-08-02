// Variables globales
let stakedNFTs = [];

// Inicialización
document.addEventListener('DOMContentLoaded', async () => {
    await initStaking();
    setupEventListeners();
});

// Inicialización del Staking
async function initStaking() {
    try {
        // Obtener NFTs en staking
        await loadStakedNFTs();
        
        // Configurar actualización automática cada 30 segundos
        setInterval(async () => {
            await loadStakedNFTs();
        }, 30000);
    } catch (error) {
        console.error('Error al inicializar staking:', error);
        showError('Error al cargar los datos de staking');
    }
}

// Configurar event listeners
function setupEventListeners() {
    const stakingForm = document.getElementById('stakingForm');
    const unstakingForm = document.getElementById('unstakingForm');
    
    if (stakingForm) {
        stakingForm.addEventListener('submit', handleStaking);
    }
    
    if (unstakingForm) {
        unstakingForm.addEventListener('submit', handleUnstaking);
    }
}

// Cargar NFTs en staking
async function loadStakedNFTs() {
    try {
        if (!contract) {
            showError('Por favor, conecta tu wallet primero');
            return;
        }
        
        // Obtener NFTs en staking del contrato
        const stakedNFTsData = await contract.getStakedNFTs(userAddress);
        stakedNFTs = stakedNFTsData;
        
        updateStakedNFTsTable();
    } catch (error) {
        console.error('Error al cargar NFTs en staking:', error);
        showError('Error al cargar NFTs en staking');
    }
}

// Actualizar tabla de NFTs en staking
function updateStakedNFTsTable() {
    const tableBody = document.getElementById('stakedNFTsTableBody');
    if (!tableBody) return;
    
    tableBody.innerHTML = '';
    
    if (stakedNFTs.length === 0) {
        tableBody.innerHTML = `
            <tr>
                <td colspan="4" class="text-center">No hay NFTs en staking</td>
            </tr>
        `;
        return;
    }
    
    stakedNFTs.forEach(nft => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${nft.id}</td>
            <td>${formatDate(nft.stakingDate)}</td>
            <td>${nft.rewards} PUNK</td>
            <td>
                <button class="btn btn-sm btn-primary" onclick="claimRewards(${nft.id})">
                    Reclamar
                </button>
            </td>
        `;
        tableBody.appendChild(row);
    });
}

// Manejar staking de NFT
async function handleStaking(event) {
    event.preventDefault();
    
    try {
        if (!contract) {
            showError('Por favor, conecta tu wallet primero');
            return;
        }
        
        const nftId = document.getElementById('nftId').value;
        
        // Aprobar NFT para staking
        const approveTx = await contract.approveNFTForStaking(nftId);
        await approveTx.wait();
        
        // Hacer stake del NFT
        const stakeTx = await contract.stakeNFT(nftId);
        await stakeTx.wait();
        
        // Actualizar lista de NFTs en staking
        await loadStakedNFTs();
        
        showSuccess('¡NFT staked con éxito!');
        event.target.reset();
    } catch (error) {
        console.error('Error al hacer stake del NFT:', error);
        showError('Error al hacer stake del NFT');
    }
}

// Manejar unstaking de NFT
async function handleUnstaking(event) {
    event.preventDefault();
    
    try {
        if (!contract) {
            showError('Por favor, conecta tu wallet primero');
            return;
        }
        
        const nftId = document.getElementById('unstakeNftId').value;
        
        // Retirar NFT del staking
        const unstakeTx = await contract.unstakeNFT(nftId);
        await unstakeTx.wait();
        
        // Actualizar lista de NFTs en staking
        await loadStakedNFTs();
        
        showSuccess('¡NFT retirado del staking con éxito!');
        event.target.reset();
    } catch (error) {
        console.error('Error al retirar NFT del staking:', error);
        showError('Error al retirar NFT del staking');
    }
}

// Reclamar recompensas
async function claimRewards(nftId) {
    try {
        if (!contract) {
            showError('Por favor, conecta tu wallet primero');
            return;
        }
        
        const tx = await contract.claimRewards(nftId);
        await tx.wait();
        
        // Actualizar lista de NFTs en staking
        await loadStakedNFTs();
        
        showSuccess('¡Recompensas reclamadas con éxito!');
    } catch (error) {
        console.error('Error al reclamar recompensas:', error);
        showError('Error al reclamar recompensas');
    }
}

// Formatear fecha
function formatDate(timestamp) {
    const date = new Date(timestamp * 1000);
    return date.toLocaleDateString('es-ES', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// Mostrar mensaje de éxito
function showSuccess(message) {
    // Aquí puedes implementar tu propia lógica para mostrar mensajes de éxito
    alert(message);
}

// Mostrar error
function showError(message) {
    // Aquí puedes implementar tu propia lógica para mostrar errores
    alert(message);
} 