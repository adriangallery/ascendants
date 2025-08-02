// Variables globales
let upgradesData = {
    fastLevel: [],
    items: []
};

// Inicialización
document.addEventListener('DOMContentLoaded', async () => {
    await initUpgrades();
});

// Inicialización de Upgrades
async function initUpgrades() {
    try {
        // Cargar datos de upgrades
        await loadUpgradesData();
        
        // Configurar actualización automática cada 30 segundos
        setInterval(async () => {
            await loadUpgradesData();
        }, 30000);
    } catch (error) {
        console.error('Error al inicializar upgrades:', error);
        showError('Error al cargar los datos de upgrades');
    }
}

// Cargar datos de upgrades
async function loadUpgradesData() {
    try {
        if (!contract) {
            showError('Por favor, conecta tu wallet primero');
            return;
        }
        
        // Obtener datos de upgrades del contrato
        const fastLevelData = await contract.getFastLevelUpgrades();
        const itemsData = await contract.getItemUpgrades();
        
        upgradesData = {
            fastLevel: fastLevelData,
            items: itemsData
        };
        
        updateUpgradesUI();
    } catch (error) {
        console.error('Error al cargar datos de upgrades:', error);
        showError('Error al cargar datos de upgrades');
    }
}

// Actualizar UI de upgrades
function updateUpgradesUI() {
    updateFastLevelUpgrades();
    updateItemUpgrades();
}

// Actualizar Fast Level Upgrades
function updateFastLevelUpgrades() {
    const container = document.getElementById('fastLevelUpgrades');
    if (!container) return;
    
    container.innerHTML = '';
    
    if (upgradesData.fastLevel.length === 0) {
        container.innerHTML = '<div class="col-12 text-center">No hay upgrades disponibles</div>';
        return;
    }
    
    upgradesData.fastLevel.forEach(upgrade => {
        const card = document.createElement('div');
        card.className = 'col-md-4 mb-3';
        card.innerHTML = `
            <div class="card h-100">
                <div class="card-body">
                    <h5 class="card-title">${upgrade.name}</h5>
                    <p class="card-text">${upgrade.description}</p>
                    <p class="card-text"><strong>Precio:</strong> ${upgrade.price} PUNK</p>
                    <p class="card-text"><strong>Bonus:</strong> ${upgrade.bonus}%</p>
                    <button class="btn btn-primary" onclick="purchaseFastLevelUpgrade(${upgrade.id})">
                        Comprar
                    </button>
                </div>
            </div>
        `;
        container.appendChild(card);
    });
}

// Actualizar Item Upgrades
function updateItemUpgrades() {
    const container = document.getElementById('itemUpgrades');
    if (!container) return;
    
    container.innerHTML = '';
    
    if (upgradesData.items.length === 0) {
        container.innerHTML = '<div class="col-12 text-center">No hay items disponibles</div>';
        return;
    }
    
    upgradesData.items.forEach(item => {
        const card = document.createElement('div');
        card.className = 'col-md-4 mb-3';
        card.innerHTML = `
            <div class="card h-100">
                <div class="card-body">
                    <h5 class="card-title">${item.name}</h5>
                    <p class="card-text">${item.description}</p>
                    <p class="card-text"><strong>Precio:</strong> ${item.price} PUNK</p>
                    <p class="card-text"><strong>Efecto:</strong> ${item.effect}</p>
                    <button class="btn btn-primary" onclick="purchaseItemUpgrade(${item.id})">
                        Comprar
                    </button>
                </div>
            </div>
        `;
        container.appendChild(card);
    });
}

// Comprar Fast Level Upgrade
async function purchaseFastLevelUpgrade(upgradeId) {
    try {
        if (!contract) {
            showError('Por favor, conecta tu wallet primero');
            return;
        }
        
        const tx = await contract.purchaseFastLevelUpgrade(upgradeId);
        await tx.wait();
        
        // Actualizar datos de upgrades
        await loadUpgradesData();
        
        showSuccess('¡Upgrade comprado con éxito!');
    } catch (error) {
        console.error('Error al comprar upgrade:', error);
        showError('Error al comprar upgrade');
    }
}

// Comprar Item Upgrade
async function purchaseItemUpgrade(itemId) {
    try {
        if (!contract) {
            showError('Por favor, conecta tu wallet primero');
            return;
        }
        
        const tx = await contract.purchaseItemUpgrade(itemId);
        await tx.wait();
        
        // Actualizar datos de upgrades
        await loadUpgradesData();
        
        showSuccess('¡Item comprado con éxito!');
    } catch (error) {
        console.error('Error al comprar item:', error);
        showError('Error al comprar item');
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