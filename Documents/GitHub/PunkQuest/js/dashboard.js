// Variables globales
let contractData = null;

// Inicialización
document.addEventListener('DOMContentLoaded', async () => {
    await initDashboard();
});

// Inicialización del Dashboard
async function initDashboard() {
    try {
        // Obtener datos del contrato
        contractData = await getContractData();
        
        if (contractData) {
            updateDashboardUI(contractData);
        }
        
        // Configurar actualización automática cada 30 segundos
        setInterval(async () => {
            contractData = await getContractData();
            if (contractData) {
                updateDashboardUI(contractData);
            }
        }, 30000);
    } catch (error) {
        console.error('Error al inicializar el dashboard:', error);
        showError('Error al cargar los datos del dashboard');
    }
}

// Actualizar la UI con los datos del contrato
function updateDashboardUI(data) {
    // Actualizar balance total
    const totalBalanceElement = document.getElementById('totalBalance');
    if (totalBalanceElement) {
        totalBalanceElement.textContent = `${data.baseRewardRate} PUNK`;
    }
    
    // Actualizar NFTs staked
    const stakedNFTsElement = document.getElementById('stakedNFTs');
    if (stakedNFTsElement) {
        stakedNFTsElement.textContent = data.stakedNFTs || '0';
    }
    
    // Actualizar recompensas pendientes
    const pendingRewardsElement = document.getElementById('pendingRewards');
    if (pendingRewardsElement) {
        pendingRewardsElement.textContent = `${data.pendingRewards || '0'} PUNK`;
    }
    
    // Actualizar tabla de staking
    updateStakingTable(data.stakingInfo || []);
}

// Actualizar la tabla de staking
function updateStakingTable(stakingInfo) {
    const tableBody = document.getElementById('stakingTableBody');
    if (!tableBody) return;
    
    tableBody.innerHTML = '';
    
    if (stakingInfo.length === 0) {
        tableBody.innerHTML = `
            <tr>
                <td colspan="4" class="text-center">No hay NFTs en staking</td>
            </tr>
        `;
        return;
    }
    
    stakingInfo.forEach(info => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${info.nftId}</td>
            <td>${formatTimeStaked(info.timeStaked)}</td>
            <td>${info.accumulatedRewards} PUNK</td>
            <td>
                <button class="btn btn-sm btn-primary" onclick="claimRewards(${info.nftId})">
                    Reclamar
                </button>
            </td>
        `;
        tableBody.appendChild(row);
    });
}

// Formatear tiempo en staking
function formatTimeStaked(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    return `${days}d ${hours}h ${minutes}m`;
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
        
        // Actualizar UI después de la transacción
        contractData = await getContractData();
        if (contractData) {
            updateDashboardUI(contractData);
        }
        
        showSuccess('¡Recompensas reclamadas con éxito!');
    } catch (error) {
        console.error('Error al reclamar recompensas:', error);
        showError('Error al reclamar recompensas');
    }
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